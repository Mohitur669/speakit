package com.tts.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.tts.exception.SpeechConversionException;
import jakarta.annotation.PostConstruct;
import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.io.ClassPathResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.*;

/**
 * Service for integrating Sarvam AI Text-to-Speech.
 * Specializes in high-quality Indian language synthesis.
 * Configuration is externalized to sarvam-voices.json.
 */
@Service
@Slf4j
public class SarvamService {

    @Value("${sarvam.apiKey:}")
    private String apiKey;

    private final String API_URL = "https://api.sarvam.ai/text-to-speech";
    private final RestTemplate restTemplate = new RestTemplate();
    private final ObjectMapper objectMapper = new ObjectMapper();

    private SarvamConfig config;

    @PostConstruct
    public void init() {
        try {
            ClassPathResource resource = new ClassPathResource("sarvam-voices.json");
            config = objectMapper.readValue(resource.getInputStream(), SarvamConfig.class);
            log.info("Sarvam AI voice configuration loaded successfully ({} speakers, {} languages).", 
                    config.getSpeakers().size(), config.getLanguages().size());
        } catch (Exception e) {
            log.error("Failed to load Sarvam AI voice configuration from sarvam-voices.json", e);
            config = new SarvamConfig(); // Empty fallback
        }
    }

    @Data
    private static class SarvamConfig {
        private List<String> speakers = new ArrayList<>();
        private List<Language> languages = new ArrayList<>();
        private List<String> female_speakers = new ArrayList<>();
    }

    @Data
    private static class Language {
        private String code;
        private String name;
    }

    /**
     * Synthesizes text into speech using Sarvam AI.
     * Returns an InputStream of the audio data.
     */
    public InputStream synthesizeSpeech(String text, String voiceId, String languageCode, Double pace, Integer samplingRate) {
        if (apiKey == null || apiKey.isEmpty()) {
            throw new SpeechConversionException("Sarvam AI API Key is missing. Please configure SARVAM_API_KEY.");
        }

        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);
        headers.set("api-subscription-key", apiKey);

        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("inputs", Collections.singletonList(text));
        requestBody.put("target_language_code", languageCode != null ? languageCode : "hi-IN");
        requestBody.put("speaker", voiceId);
        requestBody.put("model", "bulbul:v3");
        requestBody.put("audio_format", "mp3");
        
        if (pace != null) {
            requestBody.put("pace", pace);
        }
        
        if (samplingRate != null) {
            requestBody.put("sampling_rate", samplingRate);
        }

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(requestBody, headers);

        try {
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    API_URL,
                    HttpMethod.POST,
                    entity,
                    new ParameterizedTypeReference<Map<String, Object>>() {}
            );

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                Map<String, Object> body = response.getBody();
                String base64Audio = null;

                // Bulbul v3 typically returns an 'audios' array
                if (body.containsKey("audios") && body.get("audios") instanceof List<?>) {
                    List<?> audios = (List<?>) body.get("audios");
                    if (!audios.isEmpty()) {
                        base64Audio = String.valueOf(audios.get(0));
                    }
                }
                
                // Fallbacks for older models or variations
                if (base64Audio == null) {
                    base64Audio = (String) body.get("audio_content");
                }
                if (base64Audio == null) {
                    base64Audio = (String) body.get("audio_data");
                }
                
                if (base64Audio != null) {
                    byte[] audioBytes = Base64.getDecoder().decode(base64Audio);
                    return new ByteArrayInputStream(audioBytes);
                }
            }
            throw new SpeechConversionException("Failed to get audio content from Sarvam AI. Status: " + response.getStatusCode());
        } catch (Exception e) {
            log.error("Sarvam AI synthesis failed", e);
            throw new SpeechConversionException("Sarvam AI synthesis failed: " + e.getMessage());
        }
    }

    /**
     * Returns a curated list of supported Sarvam AI voices for the "Indian" filter.
     */
    public List<Map<String, Object>> getAvailableVoices() {
        if (apiKey == null || apiKey.isEmpty() || config == null) {
            return List.of();
        }

        List<Map<String, Object>> voices = new ArrayList<>();
        
        for (String speaker : config.getSpeakers()) {
            for (Language lang : config.getLanguages()) {
                Map<String, Object> map = new HashMap<>();
                
                map.put("id", speaker + ":" + lang.getCode());
                map.put("name", capitalize(speaker) + " (" + lang.getName() + ")");
                map.put("gender", isFemale(speaker) ? "Female" : "Male");
                map.put("isElevenLabs", false);
                map.put("isSarvam", true);
                map.put("languageCode", lang.getCode());
                voices.add(map);
            }
        }

        return voices;
    }

    private String capitalize(String str) {
        if (str == null || str.isEmpty()) return str;
        return str.substring(0, 1).toUpperCase() + str.substring(1);
    }

    private boolean isFemale(String speaker) {
        if (config == null || config.getFemale_speakers() == null) return false;
        return config.getFemale_speakers().contains(speaker.toLowerCase());
    }
}
