package com.tts.service;

import com.tts.exception.SpeechConversionException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.polly.PollyClient;
import software.amazon.awssdk.services.polly.model.*;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Manages integration with AWS Polly for high-performance text-to-speech synthesis.
 * 
 * Handles:
 * - Initialization of the AWS Polly Client using externalized credentials
 * - In-memory caching of available voices to reduce external API latency
 * - Enforcement of Standard vs. Neural engine constraints based on user subscription
 * - Streaming audio data back to the caller efficiently
 */
@Service
@Slf4j
public class PollyService implements SpeechProvider {

    @Value("${aws.accessKeyId}")
    private String accessKeyId;

    @Value("${aws.secretKey}")
    private String secretKey;

    @Value("${aws.region}")
    private String region;

    private PollyClient pollyClient;
    private List<Voice> cachedVoices;
    private long lastCacheUpdate = 0;
    
    // Cache duration set to 24 hours to prevent unnecessary network calls
    private static final long CACHE_DURATION = 24 * 60 * 60 * 1000;

    /**
     * Initializes the PollyClient upon service creation using injected AWS credentials.
     */
    @PostConstruct
    public void init() {
        pollyClient = PollyClient.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKeyId, secretKey)
                ))
                .build();
    }

    @Override
    public boolean supports(String engineName) {
        return "polly".equalsIgnoreCase(engineName);
    }

    @Override
    public InputStream synthesizeSpeech(String text, String voiceId, String outputFormat, Map<String, Object> additionalParams) {
        // Use provided engine if present, otherwise negotiate
        Engine engine = (additionalParams != null && additionalParams.containsKey("engine")) 
                ? (Engine) additionalParams.get("engine") 
                : getBestEngineForVoice(voiceId, null);
        
        log.info("Speech Synthesis: Using {} engine for voice={}", engine, voiceId);
        return synthesize(text, voiceId, outputFormat, engine);
    }

    /**
     * Legacy/Helper method for simple synthesis.
     * Negotiates the best available engine (Neural/Standard).
     */
    public InputStream synthesizeSpeech(String text, String voiceId, String outputFormat) {
        return synthesizeSpeech(text, voiceId, outputFormat, null);
    }

    /**
     * Centralized logic to determine the best available engine for a voice.
     * Prioritizes NEURAL for quality, but falls back to STANDARD if the user's
     * plan does not support high-cost engines.
     */
    public Engine getBestEngineForVoice(String voiceId, com.tts.entity.PlanType planType) {
        List<Voice> voices = getRawAvailableVoices();
        Voice voice = voices.stream()
                .filter(v -> v.id().toString().equals(voiceId))
                .findFirst()
                .orElse(null);

        // Security check: Only PRO/PRO_PLUS/ENTERPRISE users can use NEURAL
        boolean isPremiumPlan = planType != null && (
                planType == com.tts.entity.PlanType.PRO || 
                planType == com.tts.entity.PlanType.PRO_PLUS || 
                planType == com.tts.entity.PlanType.ENTERPRISE
        );

        if (isPremiumPlan && voice != null && voice.supportedEngines().contains(Engine.NEURAL)) {
            return Engine.NEURAL;
        }
        return Engine.STANDARD;
    }

    /**
     * Internal method that executes the physical request to the AWS Polly API.
     */
    private InputStream synthesize(String text, String voiceId, String outputFormat, Engine engine) {

        SynthesizeSpeechRequest request = SynthesizeSpeechRequest.builder()
                .text(text)
                .voiceId(VoiceId.fromValue(voiceId))
                .outputFormat(OutputFormat.fromValue(outputFormat))
                .engine(engine)
                .build();

        try {
            ResponseInputStream<SynthesizeSpeechResponse> responseStream =
                    pollyClient.synthesizeSpeech(request);

            SynthesizeSpeechResponse response = responseStream.response();

            if (response == null || response.requestCharacters() == null) {
                throw new SpeechConversionException("Invalid Polly response for voice=" + voiceId);
            }

            return responseStream;

        } catch (Exception e) {
            log.error("Polly synthesis failed [voice={}, engine={}]", voiceId, engine, e);
            throw new SpeechConversionException("Polly synthesis failed [voice=" + voiceId + ", engine=" + engine + "]");
        }
    }

    /**
     * Retrieves the list of supported voices from AWS Polly.
     * Implements a time-based cache to avoid rate limits and reduce latency.
     * 
     * @return A list of Voice objects representing the available options
     */
    @Override
    public List<Map<String, Object>> getAvailableVoices() {
        if (cachedVoices != null && (System.currentTimeMillis() - lastCacheUpdate < CACHE_DURATION)) {
            return mapVoices(cachedVoices);
        }

        try {
            DescribeVoicesRequest request = DescribeVoicesRequest.builder()
                    .languageCode(LanguageCode.EN_US)
                    .build();
            cachedVoices = pollyClient.describeVoices(request).voices();
            lastCacheUpdate = System.currentTimeMillis();
            log.info("Polly voices cache updated. Found {} voices.", cachedVoices.size());
            return mapVoices(cachedVoices);
        } catch (Exception e) {
            log.error("Failed to fetch voices from Polly", e);
            return mapVoices(cachedVoices != null ? cachedVoices : List.of());
        }
    }

    private List<Map<String, Object>> mapVoices(List<Voice> voices) {
        List<Map<String, Object>> mappedVoices = new ArrayList<>();
        for (Voice v : voices) {
            Map<String, Object> map = new HashMap<>();
            map.put("id", v.id().toString());
            map.put("name", v.name());
            map.put("gender", v.genderAsString());
            map.put("isElevenLabs", false);
            map.put("isSarvam", false);
            mappedVoices.add(map);
        }
        return mappedVoices;
    }

    public List<Voice> getRawAvailableVoices() {
        if (cachedVoices != null && (System.currentTimeMillis() - lastCacheUpdate < CACHE_DURATION)) {
            return cachedVoices;
        }

        try {
            DescribeVoicesRequest request = DescribeVoicesRequest.builder()
                    .languageCode(LanguageCode.EN_US)
                    .build();
            cachedVoices = pollyClient.describeVoices(request).voices();
            lastCacheUpdate = System.currentTimeMillis();
            return cachedVoices;
        } catch (Exception e) {
            return cachedVoices != null ? cachedVoices : List.of();
        }
    }
}
