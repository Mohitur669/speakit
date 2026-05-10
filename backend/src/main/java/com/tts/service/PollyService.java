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
import java.util.Set;

@Service
@Slf4j
public class PollyService {

    // Neural-only or problematic voices
    private static final Set<String> NEURAL_VOICES = Set.of(
            "Kevin", "Danielle", "Gregory", "Ruth", "Stephen"
    );

    @Value("${aws.accessKeyId}")
    private String accessKeyId;

    @Value("${aws.secretKey}")
    private String secretKey;

    @Value("${aws.region}")
    private String region;

    private PollyClient pollyClient;
    private List<Voice> cachedVoices;
    private long lastCacheUpdate = 0;
    private static final long CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 hours

    @PostConstruct
    public void init() {
        pollyClient = PollyClient.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKeyId, secretKey)
                ))
                .build();
    }

    public InputStream synthesizeSpeech(String text, String voiceId, String outputFormat, boolean hasNaturalAccess) {

        // Try NEURAL first if user has access AND voice supports it
        if (hasNaturalAccess) {
            // Check if voice supports NEURAL dynamically or via the NEURAL_VOICES set
            // It's better to check the actual voice capabilities if possible, but for simplicity:
            if (NEURAL_VOICES.contains(voiceId)) {
                try {
                    log.info("Using NEURAL engine for premium user, voice={}", voiceId);
                    return synthesize(text, voiceId, outputFormat, Engine.NEURAL);
                } catch (Exception e) {
                    log.warn("Neural failed for voice={}, falling back to STANDARD", voiceId, e);
                }
            }
        }

        log.info("Using STANDARD engine for voice={}", voiceId);
        return synthesize(text, voiceId, outputFormat, Engine.STANDARD);
    }

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

            // Optional but useful: validate response
            SynthesizeSpeechResponse response = responseStream.response();

            if (response == null || response.requestCharacters() == null) {
                throw new SpeechConversionException("Invalid Polly response for voice=" + voiceId);
            }

            return responseStream;

        } catch (Exception e) {
            log.debug("Polly synthesis failed [voice={}, engine={}]", voiceId, engine, e);
            throw new SpeechConversionException("Polly synthesis failed [voice=" + voiceId + ", engine=" + engine + "]");
        }
    }

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
