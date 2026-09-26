package com.speakit.stt.service;

import com.speakit.stt.dto.TranslationRequest;
import com.speakit.stt.dto.TranslationResponse;
import com.speakit.stt.exception.SttException;
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

        String sourceLanguage = normalizeLanguageCode(request.getSourceLanguage(), "auto");
        String targetLanguage = normalizeLanguageCode(request.getTargetLanguage(), "en-IN");
        if ("auto".equals(targetLanguage)) {
            targetLanguage = "en-IN";
        }

        // If source is known and equals target, return unchanged text
        if (!"auto".equals(sourceLanguage) && sourceLanguage.equalsIgnoreCase(targetLanguage)) {
            return TranslationResponse.builder()
                    .translatedText(request.getText())
                    .sourceLanguage(sourceLanguage)
                    .build();
        }

        // When source language is auto, mayura:v1 supports automatic language detection
        String model = "auto".equals(sourceLanguage) ? "mayura:v1" : "sarvam-translate:v1";

        Map<String, Object> body = new HashMap<>();
        body.put("input", request.getText());
        body.put("source_language_code", sourceLanguage);
        body.put("target_language_code", targetLanguage);
        body.put("model", model);

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
            log.warn("Sarvam translation with model={} failed: {}. Retrying with fallback model...", model, e.getMessage());
            
            // If primary model failed, try alternative model
            String fallbackModel = "mayura:v1".equals(model) ? "sarvam-translate:v1" : "mayura:v1";
            try {
                Map<String, Object> fallbackBody = new HashMap<>(body);
                fallbackBody.put("model", fallbackModel);
                // If switching to sarvam-translate:v1 and source was auto, default source to en-IN or hi-IN
                if ("auto".equals(sourceLanguage) && "sarvam-translate:v1".equals(fallbackModel)) {
                    fallbackBody.put("source_language_code", "en-IN");
                }
                
                Map<String, Object> fallbackResp = restClient.post()
                        .uri("/translate")
                        .header("api-subscription-key", apiKey)
                        .contentType(MediaType.APPLICATION_JSON)
                        .body(fallbackBody)
                        .retrieve()
                        .body(new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {});
                
                if (fallbackResp != null && fallbackResp.containsKey("translated_text")) {
                    return TranslationResponse.builder()
                            .translatedText((String) fallbackResp.get("translated_text"))
                            .sourceLanguage((String) fallbackResp.get("source_language_code"))
                            .build();
                }
            } catch (Exception retryEx) {
                log.error("Fallback translation with model={} also failed: {}", fallbackModel, retryEx.getMessage());
            }

            throw new SttException("Translation failed: " + e.getMessage());
        }
    }

    private String normalizeLanguageCode(String code, String defaultCode) {
        if (code == null || code.trim().isEmpty() || "auto".equalsIgnoreCase(code.trim())) {
            return "auto";
        }
        String clean = code.trim().toLowerCase();
        if (clean.contains("english")) return "en-IN";
        if (clean.contains("hindi")) return "hi-IN";
        if (clean.contains("bengali")) return "bn-IN";
        if (clean.contains("tamil")) return "ta-IN";
        if (clean.contains("telugu")) return "te-IN";
        if (clean.contains("marathi")) return "mr-IN";
        if (clean.contains("gujarati")) return "gu-IN";
        if (clean.contains("kannada")) return "kn-IN";
        if (clean.contains("malayalam")) return "ml-IN";
        if (clean.contains("punjabi")) return "pa-IN";
        if (clean.contains("odia")) return "od-IN";
        if (clean.contains("urdu")) return "ur-IN";
        if (clean.contains("assamese")) return "as-IN";

        clean = clean.replaceAll("[()\\s]+", "-").replaceAll("-+", "-").replaceAll("^-|-$", "");

        if (clean.contains("-")) {
            String[] parts = clean.split("-");
            return parts[0] + "-" + parts[1].toUpperCase();
        }
        return switch (clean) {
            case "en" -> "en-IN";
            case "hi" -> "hi-IN";
            case "bn" -> "bn-IN";
            case "ta" -> "ta-IN";
            case "te" -> "te-IN";
            case "mr" -> "mr-IN";
            case "gu" -> "gu-IN";
            case "kn" -> "kn-IN";
            case "ml" -> "ml-IN";
            case "pa" -> "pa-IN";
            case "or", "od" -> "od-IN";
            case "as" -> "as-IN";
            case "ur" -> "ur-IN";
            default -> clean.length() == 2 ? clean + "-IN" : defaultCode;
        };
    }
}
