package com.speakit.stt.provider;

import com.speakit.stt.dto.SpeechToTextResult;
import com.speakit.stt.exception.SttException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestClient;

import java.io.File;
import java.time.Duration;
import java.util.Map;

@Component
@Slf4j
public class SarvamSpeechToTextProvider implements SpeechToTextProvider {

    @Value("${sarvam.apiKey:}")
    private String apiKey;

    @Value("${sarvam.stt.model:saaras:v4}")
    private String sttModel;

    private final RestClient restClient;

    public SarvamSpeechToTextProvider() {
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory();
        requestFactory.setReadTimeout(Duration.ofSeconds(60));
        this.restClient = RestClient.builder()
                .baseUrl("https://api.sarvam.ai")
                .requestFactory(requestFactory)
                .build();
    }

    @Override
    public SpeechToTextResult transcribe(File audioFile, String language) {
        return transcribe(audioFile, language, null);
    }

    @Override
    public SpeechToTextResult transcribe(File audioFile, String language, String mode) {
        if (apiKey == null || apiKey.isEmpty()) {
            throw new SttException("Sarvam API Key is missing.");
        }

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", new FileSystemResource(audioFile));
        body.add("model", (sttModel != null && !sttModel.isBlank()) ? sttModel : "saaras:v4");
        if (language != null) {
            String mappedLang = "auto".equalsIgnoreCase(language) ? "unknown" : language;
            body.add("language_code", mappedLang);
        }
        if (mode != null && !mode.isBlank()) {
            body.add("mode", mode.toLowerCase().trim());
        }

        try {
            Map<String, Object> response = restClient.post()
                    .uri("/speech-to-text")
                    .header("api-subscription-key", apiKey)
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(body)
                    .retrieve()
                    .body(new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {});

            if (response != null && response.containsKey("transcript")) {
                String detectedLang = (String) response.get("language_code");
                if (detectedLang == null) {
                    detectedLang = language;
                }
                String transliteration = null;
                if (response.containsKey("transliteration")) {
                    transliteration = (String) response.get("transliteration");
                } else if ("translit".equalsIgnoreCase(mode)) {
                    transliteration = (String) response.get("transcript");
                }
                return SpeechToTextResult.builder()
                        .transcript((String) response.get("transcript"))
                        .language(detectedLang)
                        .provider(getName())
                        .duration(parseDuration(response.get("duration")))
                        .transliteration(transliteration)
                        .mode(mode != null ? mode.toLowerCase().trim() : "transcribe")
                        .build();
            }
            throw new SttException("Unexpected response from Sarvam AI");
        } catch (Exception e) {
            log.error("Sarvam STT failed: {}", e.getMessage());
            throw new SttException("Sarvam STT failed: " + e.getMessage());
        }
    }

    private Double parseDuration(Object duration) {
        if (duration instanceof Number) {
            return ((Number) duration).doubleValue();
        }
        return 0.0;
    }

    @Override
    public String getName() {
        return "SARVAM";
    }
}
