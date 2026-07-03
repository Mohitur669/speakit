package com.stt.service;

import com.tts.entity.User;
import com.tts.repository.UserRepository;
import com.stt.dto.SpeechToTextResult;
import com.stt.provider.ElevenLabsSpeechToTextProvider;
import com.stt.provider.SarvamSpeechToTextProvider;
import com.stt.repository.SpeechToTextRequestRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import java.io.File;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SttServiceTest {

    @Mock
    private SarvamSpeechToTextProvider sarvamProvider;
    @Mock
    private ElevenLabsSpeechToTextProvider elevenLabsProvider;
    @Mock
    private SpeechToTextRequestRepository sttRepository;
    @Mock
    private UserRepository userRepository;
    @Mock
    private com.tts.service.SystemParameterService systemParameterService;

    @InjectMocks
    private SttService sttService;

    @Test
    void transcribe_PrimarySuccess_NoFallback() {
        MockMultipartFile file = new MockMultipartFile("file", "test.mp3", "audio/mpeg", new byte[10]);
        SpeechToTextResult expected = SpeechToTextResult.builder()
                .transcript("Success")
                .provider("SARVAM")
                .duration(10.0)
                .build();

        lenient().when(systemParameterService.getLiveParameter(anyString(), anyString())).thenReturn("60000");
        lenient().when(sarvamProvider.getName()).thenReturn("SARVAM");
        when(sarvamProvider.transcribe(any(File.class), eq("en"))).thenReturn(expected);
        when(userRepository.getReferenceById(1L)).thenReturn(new User());

        SpeechToTextResult actual = sttService.transcribe(file, "en", 1L, null);

        assertNotNull(actual);
        assertEquals("SARVAM", actual.getProvider());
        verify(elevenLabsProvider, never()).transcribe(any(), any());
        verify(sttRepository, times(1)).save(any());
    }

    @Test
    void transcribe_PrimaryFailure_FallbackToElevenLabs() {
        MockMultipartFile file = new MockMultipartFile("file", "test.mp3", "audio/mpeg", new byte[10]);
        SpeechToTextResult expectedFallback = SpeechToTextResult.builder()
                .transcript("Fallback Success")
                .provider("ELEVEN_LABS")
                .duration(5.0)
                .build();

        lenient().when(sarvamProvider.getName()).thenReturn("SARVAM");
        lenient().when(elevenLabsProvider.getName()).thenReturn("ELEVEN_LABS");
        lenient().when(systemParameterService.getLiveParameter(anyString(), anyString())).thenReturn("60000");
        
        // Primary fails
        when(sarvamProvider.transcribe(any(File.class), eq("en"))).thenThrow(new RuntimeException("Service Down"));
        // Fallback succeeds
        when(elevenLabsProvider.transcribe(any(File.class), eq("en"))).thenReturn(expectedFallback);
        when(userRepository.getReferenceById(1L)).thenReturn(new User());

        SpeechToTextResult actual = sttService.transcribe(file, "en", 1L, null);

        assertNotNull(actual);
        assertEquals("ELEVEN_LABS", actual.getProvider());
        verify(sttRepository, times(1)).save(any());
    }
}
