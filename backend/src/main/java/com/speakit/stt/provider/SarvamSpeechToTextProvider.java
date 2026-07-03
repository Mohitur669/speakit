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
        if (apiKey == null || apiKey.isEmpty()) {
            throw new SttException("Sarvam API Key is missing.");
        }

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", new FileSystemResource(audioFile));
        body.add("model", "saarika:v2.5"); // Updated from deprecated v1
        if (language != null) {
            String mappedLang = "auto".equalsIgnoreCase(language) ? "unknown" : language;
            body.add("language_code", mappedLang);
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
                return SpeechToTextResult.builder()
                        .transcript((String) response.get("transcript"))
                        .language(detectedLang)
                        .provider(getName())
                        .duration(parseDuration(response.get("duration")))
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
