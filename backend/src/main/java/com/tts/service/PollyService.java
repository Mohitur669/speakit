package com.tts.service;

import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.polly.PollyClient;
import software.amazon.awssdk.services.polly.model.*;

import java.io.InputStream;
import java.util.List;

@Service
public class PollyService {

    @Value("${aws.accessKeyId}")
    private String accessKeyId;

    @Value("${aws.secretKey}")
    private String secretKey;

    @Value("${aws.region}")
    private String region;

    private PollyClient pollyClient;

    @PostConstruct
    public void init() {
        pollyClient = PollyClient.builder()
                .region(Region.of(region))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(accessKeyId, secretKey)
                ))
                .build();
    }

    public InputStream synthesizeSpeech(String text, String voiceId, String outputFormat) {
        SynthesizeSpeechRequest request = SynthesizeSpeechRequest.builder()
                .text(text)
                .voiceId(VoiceId.fromValue(voiceId))
                .outputFormat(OutputFormat.fromValue(outputFormat))
                .build();

        return pollyClient.synthesizeSpeech(request);
    }

    public List<Voice> getAvailableVoices() {
        DescribeVoicesRequest request = DescribeVoicesRequest.builder()
                .languageCode(LanguageCode.EN_US)
                .build();
        return pollyClient.describeVoices(request).voices();
    }
}