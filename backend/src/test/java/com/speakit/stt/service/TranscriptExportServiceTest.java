package com.speakit.stt.service;

import com.speakit.stt.entity.LiveSessionTurn;
import com.speakit.stt.entity.SpeechToTextRequest;
import com.speakit.stt.repository.LiveSessionTurnRepository;
import com.speakit.stt.repository.SpeechToTextRequestRepository;
import com.speakit.user.entity.User;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TranscriptExportServiceTest {

    @Mock
    private SpeechToTextRequestRepository sttRequestRepository;

    @Mock
    private LiveSessionTurnRepository liveSessionTurnRepository;

    private TranscriptExportService exportService;
    private User testUser;
    private SpeechToTextRequest testRequest;
    private List<LiveSessionTurn> testTurns;

    @BeforeEach
    void setUp() {
        exportService = new TranscriptExportService(sttRequestRepository, liveSessionTurnRepository);

        testUser = User.builder().id(42L).username("testuser").build();

        testRequest = SpeechToTextRequest.builder()
                .id(101L)
                .user(testUser)
                .transcript("Hello, welcome to SpeakIT AI voice generation platform. It transforms text to speech seamlessly.")
                .language("en-US")
                .audioDurationSeconds(12)
                .provider("SARVAM")
                .processingMode("dialogue")
                .build();

        LiveSessionTurn turn1 = LiveSessionTurn.builder()
                .id(1L)
                .request(testRequest)
                .turnIndex(0)
                .speakerName("Host")
                .speakerRole("PERSON_A")
                .originalText("Hello, welcome to SpeakIT AI voice generation platform.")
                .characterCount(55)
                .build();

        LiveSessionTurn turn2 = LiveSessionTurn.builder()
                .id(2L)
                .request(testRequest)
                .turnIndex(1)
                .speakerName("Guest")
                .speakerRole("PERSON_B")
                .originalText("It transforms text to speech seamlessly.")
                .characterCount(40)
                .build();

        testTurns = List.of(turn1, turn2);
    }

    @Test
    @DisplayName("Export TXT produces clean human-readable script with speaker tags")
    void testExportTxt() {
        when(sttRequestRepository.findByIdAndUserId(101L, 42L)).thenReturn(Optional.of(testRequest));
        when(liveSessionTurnRepository.findByRequestIdOrderByTurnIndexAsc(101L)).thenReturn(testTurns);

        String result = exportService.exportTranscript(101L, 42L, "TXT");

        assertNotNull(result);
        assertTrue(result.contains("[Host]: Hello, welcome to SpeakIT AI voice generation platform."));
        assertTrue(result.contains("[Guest]: It transforms text to speech seamlessly."));
    }

    @Test
    @DisplayName("Export MARKDOWN includes title, metadata block, and speaker turns")
    void testExportMarkdown() {
        when(sttRequestRepository.findByIdAndUserId(101L, 42L)).thenReturn(Optional.of(testRequest));
        when(liveSessionTurnRepository.findByRequestIdOrderByTurnIndexAsc(101L)).thenReturn(testTurns);

        String result = exportService.exportTranscript(101L, 42L, "MARKDOWN");

        assertNotNull(result);
        assertTrue(result.startsWith("# SpeakIT Transcription"));
        assertTrue(result.contains("**Language:** en-US"));
        assertTrue(result.contains("**Duration:** 12s"));
        assertTrue(result.contains("**Host:** Hello, welcome to SpeakIT AI voice generation platform."));
    }

    @Test
    @DisplayName("Export SRT generates valid SubRip subtitle format with sequence and timestamp cues")
    void testExportSrt() {
        when(sttRequestRepository.findByIdAndUserId(101L, 42L)).thenReturn(Optional.of(testRequest));
        when(liveSessionTurnRepository.findByRequestIdOrderByTurnIndexAsc(101L)).thenReturn(testTurns);

        String result = exportService.exportTranscript(101L, 42L, "SRT");

        assertNotNull(result);
        assertTrue(result.contains("1\n00:00:00,000 --> 00:00:"));
        assertTrue(result.contains("2\n00:00:"));
        assertTrue(result.contains("[Host]: Hello, welcome to SpeakIT AI voice generation platform."));
    }

    @Test
    @DisplayName("Export VTT generates standard WebVTT format starting with WEBVTT")
    void testExportVtt() {
        when(sttRequestRepository.findByIdAndUserId(101L, 42L)).thenReturn(Optional.of(testRequest));
        when(liveSessionTurnRepository.findByRequestIdOrderByTurnIndexAsc(101L)).thenReturn(testTurns);

        String result = exportService.exportTranscript(101L, 42L, "VTT");

        assertNotNull(result);
        assertTrue(result.startsWith("WEBVTT\n\n"));
        assertTrue(result.contains("<v Host>Hello, welcome to SpeakIT AI voice generation platform."));
    }
}
