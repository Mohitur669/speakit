package com.speakit.tts.service;

import com.speakit.tts.exception.SpeechConversionException;
import org.jspecify.annotations.Nullable;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
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
    private List<Map<String, Object>> cachedVoices;
    private long lastCacheUpdate = 0;

    // Cache duration: 24 hours
    private static final long CACHE_DURATION = 24 * 60 * 60 * 1000;

    public InputStream synthesizeSpeech(String text, String voiceId) {
        return synthesizeSpeech(text, voiceId, null);
    }

    /**
     * Synthesizes speech using ElevenLabs TTS.
     * When voiceStyle is provided (e.g. "excited", "sad"), wraps text with v4 direction tags:
     * &lt;voiceStyle&gt;text&lt;/voiceStyle&gt; — supported by eleven_flash_v2_5 and eleven_turbo_v2_5.
     * Voice style direction tags provide emotional performance guidance to the AI voice model.
     */
    public InputStream synthesizeSpeech(String text, String voiceId, @Nullable String voiceStyle) {
        // SEC-04: Validate voiceId is a safe alphanumeric token before concatenating
        // it into the URL to prevent outbound path traversal (CWE-22 / SSRF-lite).
        if (voiceId == null || !voiceId.matches("^[a-zA-Z0-9_-]+$")) {
            throw new IllegalArgumentException("Invalid voiceId: must be alphanumeric (a-z, A-Z, 0-9, _, -)");
        }
        String url = "https://api.elevenlabs.io/v1/text-to-speech/" + voiceId;

        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);
        headers.setContentType(MediaType.APPLICATION_JSON);

        // Apply v4 emotion direction tag if voiceStyle is specified
        String effectiveText = text;
        if (voiceStyle != null && !voiceStyle.isBlank()) {
            // Wrap text with ElevenLabs v4 direction tag for emotion-directed synthesis
            effectiveText = "<" + voiceStyle + ">" + text + "</" + voiceStyle + ">";
            log.debug("Applying ElevenLabs voice direction tag: <{}> for voiceId={}", voiceStyle, voiceId);
        }

        Map<String, Object> body = new HashMap<>();
        body.put("text", effectiveText);
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

        if (cachedVoices != null && (System.currentTimeMillis() - lastCacheUpdate < CACHE_DURATION)) {
            return cachedVoices;
        }

        String url = "https://api.elevenlabs.io/v1/voices";

        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);

        HttpEntity<Void> entity = new HttpEntity<>(headers);

        try {
            ResponseEntity<Map<String, Object>> response = restTemplate.exchange(
                    url,
                    HttpMethod.GET,
                    entity,
                    new ParameterizedTypeReference<Map<String, Object>>() {}
            );

            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                Object voicesObj = response.getBody().get("voices");
                if (voicesObj instanceof List<?>) {
                    List<?> voicesList = (List<?>) voicesObj;
                    List<Map<String, Object>> result = new ArrayList<>();
                    for (Object vObj : voicesList) {
                        if (vObj instanceof Map<?, ?>) {
                            Map<?, ?> v = (Map<?, ?>) vObj;
                            String category = String.valueOf(v.get("category"));
                            
                            // ElevenLabs "library" or community voices often return 402 for non-paid ElevenLabs accounts
                            // We will only include 'premade' voices to ensure high reliability.
                            if (!"premade".equalsIgnoreCase(category)) {
                                continue;
                            }

                            Map<String, Object> map = new HashMap<>();
                            map.put("id", v.get("voice_id"));
                            map.put("name", v.get("name"));
                            
                            String gender = "neutral";
                            String langCode = "en-US";
                            String langName = "International English";
                            
                            Object labelsObj = v.get("labels");
                            if (labelsObj instanceof Map<?, ?> labelsMap) {
                                if (labelsMap.get("gender") != null) {
                                    String g = String.valueOf(labelsMap.get("gender")).trim().toLowerCase();
                                    if (g.contains("female") || g.contains("woman")) {
                                        gender = "Female";
                                    } else if (g.contains("male") || g.contains("man")) {
                                        gender = "Male";
                                    }
                                }
                                if (labelsMap.get("accent") != null) {
                                    langName = capitalize(String.valueOf(labelsMap.get("accent"))) + " English";
                                }
                            }
                            
                            map.put("gender", gender);
                            map.put("languageCode", langCode);
                            map.put("languageName", langName);
                            map.put("engine", "elevenlabs");
                            map.put("isNeural", true);
                            map.put("isStandard", false);
                            map.put("isElevenLabs", true);
                            map.put("isSarvam", false);
                            result.add(map);
                        }
                    }
                    cachedVoices = result;
                    lastCacheUpdate = System.currentTimeMillis();
                    log.info("ElevenLabs voices cache updated. Found {} voices.", cachedVoices.size());
                    return cachedVoices;
                }
            }
        } catch (Exception e) {
            log.warn("ElevenLabs: API Key restricted or invalid. Voices disabled. Message: {}", e.getMessage());
            return cachedVoices != null ? cachedVoices : List.of();
        }
        return List.of();
    }

    private String capitalize(String str) {
        if (str == null || str.isEmpty()) return "";
        return str.substring(0, 1).toUpperCase() + str.substring(1);
    }

    /**
     * Isolates voice from background noise using ElevenLabs Audio Isolation API.
     * Plan Gating: PRO and above.
     */
    public byte[] isolateAudio(byte[] audioBytes, String filename) {
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("ElevenLabs apiKey not configured; returning original audio for isolation");
            return audioBytes;
        }

        String url = "https://api.elevenlabs.io/v1/audio-isolation";
        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("audio", new ByteArrayResource(audioBytes) {
            @Override
            public String getFilename() {
                return filename != null ? filename : "input.mp3";
            }
        });

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);
        try {
            ResponseEntity<byte[]> response = restTemplate.exchange(url, HttpMethod.POST, entity, byte[].class);
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return response.getBody();
            }
            throw new SpeechConversionException("ElevenLabs audio isolation returned: " + response.getStatusCode());
        } catch (Exception e) {
            log.error("ElevenLabs audio isolation failed", e);
            throw new SpeechConversionException("Audio isolation failed: " + e.getMessage());
        }
    }

    /**
     * Speech-to-Speech (STS / Voice Changer) using ElevenLabs.
     * Plan Gating: PRO_PLUS and above.
     */
    public byte[] speechToSpeech(byte[] audioBytes, String filename, String voiceId) {
        if (voiceId == null || !voiceId.matches("^[a-zA-Z0-9_-]+$")) {
            throw new IllegalArgumentException("Invalid voiceId: must be alphanumeric (a-z, A-Z, 0-9, _, -)");
        }
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("ElevenLabs apiKey not configured; returning original audio for STS");
            return audioBytes;
        }

        String url = "https://api.elevenlabs.io/v1/speech-to-speech/" + voiceId;
        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("audio", new ByteArrayResource(audioBytes) {
            @Override
            public String getFilename() {
                return filename != null ? filename : "voice.mp3";
            }
        });
        body.add("model_id", "eleven_multilingual_sts_v2");

        HttpEntity<MultiValueMap<String, Object>> entity = new HttpEntity<>(body, headers);
        try {
            ResponseEntity<byte[]> response = restTemplate.exchange(url, HttpMethod.POST, entity, byte[].class);
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return response.getBody();
            }
            throw new SpeechConversionException("ElevenLabs speech-to-speech returned: " + response.getStatusCode());
        } catch (Exception e) {
            log.error("ElevenLabs speech-to-speech failed", e);
            throw new SpeechConversionException("Speech-to-Speech conversion failed: " + e.getMessage());
        }
    }

    /**
     * Generates Sound Effects from a text prompt using ElevenLabs Sound Generation API.
     * Plan Gating: PRO_PLUS and above.
     */
    public byte[] generateSoundEffect(String prompt, Double durationSeconds) {
        if (prompt == null || prompt.isBlank()) {
            throw new IllegalArgumentException("Prompt must not be empty");
        }
        if (apiKey == null || apiKey.isBlank()) {
            log.warn("ElevenLabs apiKey not configured; sound effects requires configured API key");
            throw new SpeechConversionException("ElevenLabs Sound Effects service unconfigured.");
        }

        String url = "https://api.elevenlabs.io/v1/sound-generation";
        HttpHeaders headers = new HttpHeaders();
        headers.set("xi-api-key", apiKey);
        headers.setContentType(MediaType.APPLICATION_JSON);

        Map<String, Object> body = new HashMap<>();
        body.put("text", prompt.trim());
        if (durationSeconds != null && durationSeconds > 0) {
            body.put("duration_seconds", Math.min(22.0, Math.max(0.5, durationSeconds)));
        }

        HttpEntity<Map<String, Object>> entity = new HttpEntity<>(body, headers);
        try {
            ResponseEntity<byte[]> response = restTemplate.exchange(url, HttpMethod.POST, entity, byte[].class);
            if (response.getStatusCode() == HttpStatus.OK && response.getBody() != null) {
                return response.getBody();
            }
            throw new SpeechConversionException("ElevenLabs sound generation returned: " + response.getStatusCode());
        } catch (Exception e) {
            log.error("ElevenLabs sound generation failed", e);
            throw new SpeechConversionException("Sound generation failed: " + e.getMessage());
        }
    }
}
