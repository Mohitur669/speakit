package com.tts.stt.service;

import com.tts.stt.dto.TranslationRequest;
import com.tts.stt.dto.TranslationResponse;
import com.tts.stt.exception.SttException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

@Service
@Slf4j
public class TranslationService {

    @Value("${sarvam.apiKey:}")
    private String apiKey;

    private final RestClient restClient;

    public TranslationService() {
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory();
        requestFactory.setReadTimeout(Duration.ofSeconds(20));
        this.restClient = RestClient.builder()
                .baseUrl("https://api.sarvam.ai")
                .requestFactory(requestFactory)
                .build();
    }

    public TranslationResponse translate(TranslationRequest request) {
        if (apiKey == null || apiKey.isEmpty()) {
            throw new SttException("Sarvam API Key is missing. Translation is unavailable.");
        }

        if (request.getText() == null || request.getText().trim().isEmpty()) {
            return TranslationResponse.builder()
                    .translatedText("")
                    .sourceLanguage(request.getSourceLanguage())
                    .build();
        }

        String sourceLanguage = request.getSourceLanguage();
        if (sourceLanguage == null || sourceLanguage.trim().isEmpty() || "auto".equalsIgnoreCase(sourceLanguage)) {
            sourceLanguage = "auto";
        }
        
        String targetLanguage = request.getTargetLanguage();
        if (targetLanguage == null || targetLanguage.trim().isEmpty()) {
            targetLanguage = "en-IN"; // Default to English (IN)
        }

        Map<String, Object> body = new HashMap<>();
        body.put("input", request.getText());
        body.put("source_language_code", sourceLanguage);
        body.put("target_language_code", targetLanguage);
        body.put("model", "sarvam-translate:v1");

        try {
            Map<String, Object> response = restClient.post()
                    .uri("/translate")
                    .header("api-subscription-key", apiKey)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(body)
                    .retrieve()
                    .body(new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {});

            if (response != null && response.containsKey("translated_text")) {
                return TranslationResponse.builder()
                        .translatedText((String) response.get("translated_text"))
                        .sourceLanguage((String) response.get("source_language_code"))
                        .build();
            }
            throw new SttException("Unexpected response from Sarvam translation API.");
        } catch (Exception e) {
            log.error("Sarvam translation failed: {}", e.getMessage());
            throw new SttException("Translation failed: " + e.getMessage());
        }
    }
}
