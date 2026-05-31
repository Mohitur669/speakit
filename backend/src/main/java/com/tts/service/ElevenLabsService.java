package com.tts.service;

import com.tts.exception.SpeechConversionException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Service for ElevenLabs TTS integration.
 * Enables high-quality AI voices for premium tiers.
 */
@Service
@Slf4j
public class ElevenLabsService {

    @Value("${elevenlabs.apiKey:}")
    private String apiKey;

    private final RestTemplate restTemplate = new RestTemplate();

    public InputStream synthesizeSpeech(String text, String voiceId) {
        String url = "https://api.elevenlabs.io/v1/text-to-speech/" + voiceId;

        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);
        headers.setContentType(MediaType.APPLICATION_JSON);

        Map<String, Object> body = new HashMap<>();
        body.put("text", text);
        body.put("model_id", "eleven_flash_v2_5");
        
        Map<String, Object> voiceSettings = new HashMap<>();
        voiceSettings.put("stability", 0.5);
        voiceSettings.put("similarity_boost", 0.75);
        body.put("voice_settings", voiceSettings);

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);

        try {
            ResponseEntity<byte[]> response = restTemplate.exchange(url, HttpMethod.POST, entity, byte[].class);
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return new ByteArrayInputStream(response.getBody());
            }
            throw new SpeechConversionException("ElevenLabs returned status: " + response.getStatusCode());
        } catch (Exception e) {
            log.error("ElevenLabs synthesis failed", e);
            throw new SpeechConversionException("ElevenLabs synthesis failed: " + e.getMessage());
        }
    }

    public List<Map<String, Object>> getAvailableVoices() {
        if (apiKey == null || apiKey.isBlank()) {
            return List.of();
        }

        String url = "https://api.elevenlabs.io/v1/voices";

        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);

        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<Map> response = restTemplate.exchange(url, HttpMethod.GET, entity, Map.class);
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                List<Map<String, Object>> voices = (List<Map<String, Object>>) response.getBody().get("voices");
                List<Map<String, Object>> result = new ArrayList<>();
                for (Map<String, Object> v : voices) {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", v.get("voice_id"));
                    map.put("name", v.get("name"));
                    map.put("gender", "neutral"); // ElevenLabs doesn't always provide this clearly in basic list
                    map.put("isNeural", true);
                    map.put("isStandard", false);
                    map.put("isElevenLabs", true);
                    result.add(map);
                }
                return result;
            }
        } catch (Exception e) {
            log.warn("ElevenLabs: API Key restricted or invalid. Voices disabled. Message: {}", e.getMessage());
        }
        return List.of();
    }
}
