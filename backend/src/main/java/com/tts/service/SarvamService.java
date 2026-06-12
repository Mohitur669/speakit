package com.tts.service;

import com.tts.exception.SpeechConversionException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.*;

/**
 * Service for integrating Sarvam AI Text-to-Speech.
 * Specializes in high-quality Indian language synthesis.
 */
@Service
@Slf4j
public class SarvamService {

    @Value("${sarvam.apiKey:}")
    private String apiKey;

    private final String API_URL = "https://api.sarvam.ai/text-to-speech";
    private final RestTemplate restTemplate = new RestTemplate();

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
                String base64Audio = (String) response.getBody().get("audio_content");
                if (base64Audio == null) {
                    // Fallback to audio_data if audio_content is null (some docs mention audio_data)
                    base64Audio = (String) response.getBody().get("audio_data");
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
        if (apiKey == null || apiKey.isEmpty()) {
            return List.of();
        }

        List<Map<String, Object>> voices = new ArrayList<>();
        
        // Curated speakers based on documentation
        String[] speakers = {"meera", "shubh", "aditya", "ritu", "priya", "neha", "rahul", "pooja", "rohan", "simran"};
        
        // Supported Indian language codes
        Map<String, String> languages = new LinkedHashMap<>();
        languages.put("hi-IN", "Hindi");
        languages.put("bn-IN", "Bengali");
        languages.put("mr-IN", "Marathi");
        languages.put("ta-IN", "Tamil");
        languages.put("te-IN", "Telugu");
        languages.put("kn-IN", "Kannada");
        languages.put("ml-IN", "Malayalam");
        languages.put("gu-IN", "Gujarati");
        languages.put("pa-IN", "Punjabi");
        languages.put("or-IN", "Odia");

        // Generate voices for the main languages
        for (String speaker : speakers) {
            for (Map.Entry<String, String> entry : languages.entrySet()) {
                Map<String, Object> map = new HashMap<>();
                String langCode = entry.getKey();
                String langName = entry.getValue();
                
                map.put("id", speaker);
                map.put("name", capitalize(speaker) + " (" + langName + ")");
                map.put("gender", isFemale(speaker) ? "Female" : "Male");
                map.put("isElevenLabs", false);
                map.put("isSarvam", true);
                map.put("languageCode", langCode);
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
        List<String> females = Arrays.asList("meera", "ritu", "priya", "neha", "pooja", "simran", "anushka", "manisha", "vidya", "arya");
        return females.contains(speaker.toLowerCase());
    }
}
