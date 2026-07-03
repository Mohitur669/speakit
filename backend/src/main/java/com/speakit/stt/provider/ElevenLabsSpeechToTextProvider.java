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
public class ElevenLabsSpeechToTextProvider implements SpeechToTextProvider {

    @Value("${elevenlabs.apiKey:}")
    private String apiKey;

    private final RestClient restClient;

    public ElevenLabsSpeechToTextProvider() {
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory();
        requestFactory.setReadTimeout(Duration.ofSeconds(60));
        this.restClient = RestClient.builder()
                .baseUrl("https://api.elevenlabs.io/v1")
                .requestFactory(requestFactory)
                .build();
    }

    @Override
    public SpeechToTextResult transcribe(File audioFile, String language) {
        if (apiKey == null || apiKey.isEmpty()) {
            throw new SttException("ElevenLabs API Key is missing.");
        }

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", new FileSystemResource(audioFile));
        body.add("model_id", "scribe_v1"); // Based on ElevenLabs Scribe docs
        
        // Language is optional for Scribe as it auto-detects, but can be forced
        if (language != null) {
            String mappedLang = mapToElevenLabsLanguage(language);
            if (mappedLang != null) {
                log.debug("Mapping input language {} to ElevenLabs compatible {}", language, mappedLang);
                body.add("language_code", mappedLang);
            }
        }

        try {
            Map<String, Object> response = restClient.post()
                    .uri("/speech-to-text")
                    .header("xi-api-key", apiKey)
                    .contentType(MediaType.MULTIPART_FORM_DATA)
                    .body(body)
                    .retrieve()
                    .body(new org.springframework.core.ParameterizedTypeReference<Map<String, Object>>() {});

            if (response != null && response.containsKey("text")) {
                String detectedLang = (String) response.get("language_code");
                if (detectedLang == null) {
                    detectedLang = language;
                }
                return SpeechToTextResult.builder()
                        .transcript((String) response.get("text"))
                        .language(detectedLang)
                        .provider(getName())
                        .duration(0.0) // ElevenLabs might not return duration in the same way
                        .build();
            }
            throw new SttException("Unexpected response from ElevenLabs Scribe");
        } catch (Exception e) {
            log.error("ElevenLabs STT failed: {}", e.getMessage());
            throw new SttException("ElevenLabs STT failed: " + e.getMessage());
        }
    }

    private String mapToElevenLabsLanguage(String lang) {
        if (lang == null || "auto".equalsIgnoreCase(lang)) return null;
        return switch (lang.toLowerCase()) {
            case "en-in" -> "eng";
            case "hi-in" -> "hin";
            case "bn-in" -> "ben";
            case "ta-in" -> "tam";
            case "te-in" -> "tel";
            case "mr-in" -> "mar";
            case "kn-in" -> "kan";
            case "gu-in" -> "guj";
            default -> lang.length() > 3 ? lang.substring(0, 3) : lang;
        };
    }

    @Override
    public String getName() {
        return "ELEVEN_LABS";
    }
}
