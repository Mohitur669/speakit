package com.speakit.stt.service;

import com.speakit.stt.dto.TranslationRequest;
import com.speakit.stt.dto.TranslationResponse;
import com.speakit.stt.dto.TransliterationRequest;
import com.speakit.stt.dto.TransliterationResponse;
import com.speakit.stt.exception.SttException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

class TranslationServiceTest {

    private TranslationService translationService;

    @BeforeEach
    void setUp() {
        translationService = new TranslationService();
    }

    @Test
    void translate_ThrowsExceptionWhenApiKeyMissing() {
        ReflectionTestUtils.setField(translationService, "apiKey", "");
        TranslationRequest request = TranslationRequest.builder()
                .text("Hello world")
                .sourceLanguage("en-IN")
                .targetLanguage("hi-IN")
                .build();

        assertThrows(SttException.class, () -> translationService.translate(request));
    }

    @Test
    void translate_ReturnsEmptyWhenTextEmpty() {
        ReflectionTestUtils.setField(translationService, "apiKey", "test-key");
        TranslationRequest request = TranslationRequest.builder()
                .text("")
                .sourceLanguage("en-IN")
                .targetLanguage("hi-IN")
                .build();

        TranslationResponse response = translationService.translate(request);
        assertNotNull(response);
        assertEquals("", response.getTranslatedText());
    }

    @Test
    void translate_ReturnsSameTextWhenSourceEqualsTarget() {
        ReflectionTestUtils.setField(translationService, "apiKey", "test-key");
        TranslationRequest request = TranslationRequest.builder()
                .text("Namaste")
                .sourceLanguage("hi-IN")
                .targetLanguage("hi-IN")
                .build();

        TranslationResponse response = translationService.translate(request);
        assertNotNull(response);
        assertEquals("Namaste", response.getTranslatedText());
        assertEquals("hi-IN", response.getSourceLanguage());
    }

    @Test
    void transliterate_ThrowsExceptionWhenApiKeyMissing() {
        ReflectionTestUtils.setField(translationService, "apiKey", "");
        TransliterationRequest request = TransliterationRequest.builder()
                .text("Namaste")
                .sourceLanguage("hi-IN")
                .targetLanguage("en-IN")
                .build();

        assertThrows(SttException.class, () -> translationService.transliterate(request));
    }

    @Test
    void transliterate_ReturnsEmptyWhenTextEmpty() {
        ReflectionTestUtils.setField(translationService, "apiKey", "test-key");
        TransliterationRequest request = TransliterationRequest.builder()
                .text("  ")
                .sourceLanguage("hi-IN")
                .targetLanguage("en-IN")
                .build();

        TransliterationResponse response = translationService.transliterate(request);
        assertNotNull(response);
        assertEquals("", response.getTransliteratedText());
    }
}
