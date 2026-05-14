package com.tts.service;

/**
 * AWS Polly integration service handling voice metadata
 * fetching and speech synthesis with standard/neural engines.
 */
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
        
        // Find voice in cache to check capabilities
        List<Voice> voices = getAvailableVoices();
        Voice voice = voices.stream()
                .filter(v -> v.id().toString().equals(voiceId))
                .findFirst()
                .orElse(null);

        Engine engine = Engine.STANDARD;
        
        if (hasNaturalAccess && voice != null && voice.supportedEngines().contains(Engine.NEURAL)) {
            engine = Engine.NEURAL;
            log.info("Server Enforced: Using NEURAL engine for premium user, voice={}", voiceId);
        } else {
            log.info("Server Enforced: Using STANDARD engine for voice={}", voiceId);
        }

        return synthesize(text, voiceId, outputFormat, engine);
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
