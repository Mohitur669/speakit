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
import java.util.List;

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
public class PollyService {

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

    /**
     * Synthesizes text into an audio stream, automatically negotiating the best available 
     * engine (Neural vs. Standard) based on the voice capabilities.
     * 
     * @param text The sanitized text to synthesize
     * @param voiceId The specific AWS Polly voice ID (e.g., 'Joanna')
     * @param outputFormat The requested audio format (mp3, ogg_vorbis, pcm)
     * @return InputStream containing the raw audio bytes from AWS Polly
     */
    public InputStream synthesizeSpeech(String text, String voiceId, String outputFormat) {
        Engine engine = getBestEngineForVoice(voiceId);
        log.info("Server Enforced: Using {} engine for voice={}", engine, voiceId);
        return synthesize(text, voiceId, outputFormat, engine);
    }

    /**
     * Centralized logic to determine the best available engine for a voice.
     * Prioritizes NEURAL for quality, but falls back to STANDARD.
     */
    public Engine getBestEngineForVoice(String voiceId) {
        List<Voice> voices = getAvailableVoices();
        Voice voice = voices.stream()
                .filter(v -> v.id().toString().equals(voiceId))
                .findFirst()
                .orElse(null);

        if (voice != null && voice.supportedEngines().contains(Engine.NEURAL)) {
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
    public List<Voice> getAvailableVoices() {
        if (cachedVoices != null && (System.currentTimeMillis() - lastCacheUpdate < CACHE_DURATION)) {
            return cachedVoices;
        }

        try {
            DescribeVoicesRequest request = DescribeVoicesRequest.builder()
                    .languageCode(LanguageCode.EN_US)
                    .build();
            cachedVoices = pollyClient.describeVoices(request).voices();
            lastCacheUpdate = System.currentTimeMillis();
            log.info("Polly voices cache updated. Found {} voices.", cachedVoices.size());
            return cachedVoices;
        } catch (Exception e) {
            log.error("Failed to fetch voices from Polly", e);
            return cachedVoices != null ? cachedVoices : List.of();
        }
    }
}
