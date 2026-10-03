package com.speakit.tts.controller;

import com.speakit.stt.entity.SpeechToTextRequest;
import com.speakit.stt.repository.SpeechToTextRequestRepository;
import com.speakit.tts.dto.TtsHistoryDto;
import com.speakit.tts.entity.TtsHistory;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.tts.service.AudioStorageService;
import com.speakit.tts.service.ElevenLabsService;
import com.speakit.tts.service.PollyService;
import com.speakit.tts.service.SarvamService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.web.PagedModel;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.time.LocalDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class HistoryControllerTest {

    @Mock
    private TtsHistoryRepository ttsHistoryRepository;

    @Mock
    private SpeechToTextRequestRepository speechToTextRequestRepository;

    @Mock
    private AudioStorageService audioStorageService;

    @Mock
    private PollyService pollyService;

    @Mock
    private ElevenLabsService elevenLabsService;

    @Mock
    private SarvamService sarvamService;

    @Mock
    private HttpServletRequest httpRequest;

    private HistoryController historyController;

    private final Long userId = 42L;

    @BeforeEach
    void setUp() {
        historyController = new HistoryController(
                ttsHistoryRepository,
                speechToTextRequestRepository,
                audioStorageService,
                pollyService,
                elevenLabsService,
                sarvamService
        );
        when(httpRequest.getAttribute("userId")).thenReturn(userId);
    }

    @Test
    void testGetHistory_All_MergesTtsAndStt() {
        LocalDateTime now = LocalDateTime.now();
        TtsHistory ttsItem = TtsHistory.builder()
                .id(1L)
                .voiceId("Joanna")
                .voiceName("Joanna")
                .voiceType("NEURAL")
                .characterCount(25)
                .textSnippet("Hello from TTS")
                .createdAt(now.minusHours(1))
                .build();

        SpeechToTextRequest sttItem = SpeechToTextRequest.builder()
                .id(2L)
                .provider("SARVAM")
                .language("hi-IN")
                .transcript("नमस्ते दुनिया")
                .transliteration("namaste duniya")
                .processingMode("transcribe")
                .transcriptLength(12)
                .status("SUCCESS")
                .createdAt(now)
                .build();

        when(ttsHistoryRepository.findRecentHistoryByUserId(eq(userId), any(PageRequest.class)))
                .thenReturn(new PageImpl<>(List.of(ttsItem)));
        when(speechToTextRequestRepository.findByUserIdOrderByCreatedAtDesc(eq(userId), any(PageRequest.class)))
                .thenReturn(new PageImpl<>(List.of(sttItem)));

        ResponseEntity<PagedModel<TtsHistoryDto>> response = historyController.getHistory(httpRequest, 0, 10, "ALL");

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        List<TtsHistoryDto> items = response.getBody().getContent().stream().toList();
        assertEquals(2, items.size());

        // STT was created 'now', TTS was created 'now - 1h', so STT should come first
        assertEquals("STT", items.get(0).getEngineType());
        assertEquals("नमस्ते दुनिया", items.get(0).getFullText());
        assertEquals("namaste duniya", items.get(0).getTransliteration());
        assertEquals("Sarvam Saaras", items.get(0).getVoiceName());

        assertEquals("TTS", items.get(1).getEngineType());
        assertEquals("Hello from TTS", items.get(1).getTextSnippet());
    }

    @Test
    void testGetHistory_TtsOnly() {
        TtsHistory ttsItem = TtsHistory.builder()
                .id(1L)
                .voiceId("Joanna")
                .voiceName("Joanna")
                .voiceType("NEURAL")
                .characterCount(25)
                .textSnippet("Hello from TTS")
                .createdAt(LocalDateTime.now())
                .build();

        when(ttsHistoryRepository.findRecentHistoryByUserId(eq(userId), any(PageRequest.class)))
                .thenReturn(new PageImpl<>(List.of(ttsItem)));

        ResponseEntity<PagedModel<TtsHistoryDto>> response = historyController.getHistory(httpRequest, 0, 10, "TTS");

        assertEquals(HttpStatus.OK, response.getStatusCode());
        List<TtsHistoryDto> items = response.getBody().getContent().stream().toList();
        assertEquals(1, items.size());
        assertEquals("TTS", items.get(0).getEngineType());
        verify(speechToTextRequestRepository, never()).findByUserIdOrderByCreatedAtDesc(any(), any());
    }

    @Test
    void testGetHistory_SttOnly() {
        SpeechToTextRequest sttItem = SpeechToTextRequest.builder()
                .id(2L)
                .provider("SARVAM")
                .language("hi-IN")
                .transcript("नमस्ते")
                .status("SUCCESS")
                .createdAt(LocalDateTime.now())
                .build();

        when(speechToTextRequestRepository.findByUserIdOrderByCreatedAtDesc(eq(userId), any(PageRequest.class)))
                .thenReturn(new PageImpl<>(List.of(sttItem)));

        ResponseEntity<PagedModel<TtsHistoryDto>> response = historyController.getHistory(httpRequest, 0, 10, "STT");

        assertEquals(HttpStatus.OK, response.getStatusCode());
        List<TtsHistoryDto> items = response.getBody().getContent().stream().toList();
        assertEquals(1, items.size());
        assertEquals("STT", items.get(0).getEngineType());
        verify(ttsHistoryRepository, never()).findRecentHistoryByUserId(any(), any());
    }

    @Test
    void testDeleteSelected_All() {
        List<Long> ids = List.of(1L, 2L);
        when(ttsHistoryRepository.findAllByIdInAndUserId(ids, userId)).thenReturn(List.of());

        ResponseEntity<Void> response = historyController.deleteSelected(httpRequest, ids, "ALL");

        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(ttsHistoryRepository).deleteAllByIdInAndUserId(ids, userId);
        verify(speechToTextRequestRepository).deleteAllByIdInAndUserId(ids, userId);
    }

    @Test
    void testClearAll_All() {
        when(ttsHistoryRepository.findAllByUserId(userId)).thenReturn(List.of());

        ResponseEntity<Void> response = historyController.clearAll(httpRequest, "ALL");

        assertEquals(HttpStatus.NO_CONTENT, response.getStatusCode());
        verify(ttsHistoryRepository).deleteAllByUserId(userId);
        verify(speechToTextRequestRepository).deleteAllByUserId(userId);
    }
}
