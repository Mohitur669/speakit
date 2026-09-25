package com.speakit.tts.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.test.util.ReflectionTestUtils;

import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class SarvamServiceTest {

    private SarvamService sarvamService;

    @BeforeEach
    void setUp() {
        sarvamService = new SarvamService();
        ReflectionTestUtils.setField(sarvamService, "apiKey", "test-key");
        sarvamService.init();
    }

    @Test
    void init_LoadsSpeakersAndLanguagesCorrectly() {
        List<Map<String, Object>> voices = sarvamService.getAvailableVoices();
        assertFalse(voices.isEmpty(), "Available voices should not be empty");

        // 37 speakers * 11 languages = 407 voices
        assertEquals(37 * 11, voices.size());

        // Verify niharika is not present
        boolean hasNiharika = voices.stream().anyMatch(v -> String.valueOf(v.get("id")).startsWith("niharika"));
        assertFalse(hasNiharika, "niharika should be removed from bulbul:v3 catalog");

        // Verify Indian English (en-IN) is present
        boolean hasIndianEnglish = voices.stream().anyMatch(v -> "en-IN".equals(v.get("languageCode")));
        assertTrue(hasIndianEnglish, "en-IN should be present in languages");
    }

    @Test
    void resolveSpeaker_MapsAditiToRitu() {
        assertEquals("ritu", sarvamService.resolveSpeaker("aditi"));
        assertEquals("ritu", sarvamService.resolveSpeaker("Aditi"));
        assertEquals("ritu", sarvamService.resolveSpeaker("ADITI"));
    }

    @Test
    void resolveSpeaker_MapsAnanyaToPriya() {
        assertEquals("priya", sarvamService.resolveSpeaker("ananya"));
        assertEquals("priya", sarvamService.resolveSpeaker("Ananya"));
    }

    @Test
    void resolveSpeaker_MapsNiharikaToRupali() {
        assertEquals("rupali", sarvamService.resolveSpeaker("niharika"));
    }

    @Test
    void resolveSpeaker_PassesThroughValidSpeaker() {
        assertEquals("aditya", sarvamService.resolveSpeaker("aditya"));
        assertEquals("shubh", sarvamService.resolveSpeaker("shubh"));
        assertEquals("priya", sarvamService.resolveSpeaker("priya"));
    }

    @Test
    void resolveSpeaker_FallsBackOnUnknownSpeaker() {
        assertEquals("shubh", sarvamService.resolveSpeaker("completely_random_voice"));
        assertEquals("shubh", sarvamService.resolveSpeaker(null));
        assertEquals("shubh", sarvamService.resolveSpeaker("   "));
    }

    @Test
    void normalizeLanguageCode_NormalizesCommonCodes() {
        assertEquals("en-IN", sarvamService.normalizeLanguageCode("en-US"));
        assertEquals("en-IN", sarvamService.normalizeLanguageCode("en-GB"));
        assertEquals("en-IN", sarvamService.normalizeLanguageCode("en"));
        assertEquals("en-IN", sarvamService.normalizeLanguageCode("en-IN"));
        assertEquals("hi-IN", sarvamService.normalizeLanguageCode("hi"));
        assertEquals("hi-IN", sarvamService.normalizeLanguageCode("hi-IN"));
        assertEquals("od-IN", sarvamService.normalizeLanguageCode("od-IN"));
        assertEquals("od-IN", sarvamService.normalizeLanguageCode("or"));
        assertEquals("od-IN", sarvamService.normalizeLanguageCode("or-IN"));
        assertEquals("hi-IN", sarvamService.normalizeLanguageCode(null));
        assertEquals("hi-IN", sarvamService.normalizeLanguageCode(""));
    }
}
