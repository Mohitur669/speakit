package com.speakit.tts.service;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;

import static org.junit.jupiter.api.Assertions.*;

@ExtendWith(MockitoExtension.class)
class ElevenLabsServiceTest {

    @InjectMocks
    private ElevenLabsService elevenLabsService;

    @BeforeEach
    void setUp() {
        // Leave apiKey blank to test graceful offline/unconfigured fallbacks
        ReflectionTestUtils.setField(elevenLabsService, "apiKey", "");
    }

    @Test
    void isolateAudio_NoApiKey_ReturnsOriginalAudio() {
        byte[] input = new byte[]{1, 2, 3, 4};
        byte[] result = elevenLabsService.isolateAudio(input, "test.mp3");
        assertArrayEquals(input, result);
    }

    @Test
    void speechToSpeech_NoApiKey_ReturnsOriginalAudio() {
        byte[] input = new byte[]{5, 6, 7, 8};
        byte[] result = elevenLabsService.speechToSpeech(input, "test.mp3", "validVoiceId");
        assertArrayEquals(input, result);
    }

    @Test
    void speechToSpeech_InvalidVoiceId_ThrowsException() {
        byte[] input = new byte[]{1, 2};
        assertThrows(IllegalArgumentException.class, () ->
                elevenLabsService.speechToSpeech(input, "test.mp3", "invalid!voice@id")
        );
    }

    @Test
    void generateSoundEffect_EmptyPrompt_ThrowsException() {
        assertThrows(IllegalArgumentException.class, () ->
                elevenLabsService.generateSoundEffect("", 3.0)
        );
    }

    @Test
    void getAvailableVoices_BlankKey_ReturnsEmpty() {
        var voices = elevenLabsService.getAvailableVoices();
        assertNotNull(voices);
        assertTrue(voices.isEmpty());
    }
}
