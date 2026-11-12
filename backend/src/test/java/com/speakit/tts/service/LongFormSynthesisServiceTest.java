package com.speakit.tts.service;

import com.speakit.billing.entity.PlanType;
import com.speakit.tts.dto.LongFormJobStatusDto;
import com.speakit.tts.dto.TtsRequest;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.io.ByteArrayInputStream;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LongFormSynthesisServiceTest {

    @Mock
    private PollyService pollyService;

    @Mock
    private AudioStorageService audioStorageService;

    @Mock
    private TtsHistoryRepository ttsHistoryRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PdfProcessingService pdfProcessingService;

    @Mock
    private ElevenLabsService elevenLabsService;

    @Mock
    private SarvamService sarvamService;

    private LongFormSynthesisService longFormSynthesisService;

    @BeforeEach
    void setUp() {
        longFormSynthesisService = new LongFormSynthesisService(
                pollyService,
                audioStorageService,
                ttsHistoryRepository,
                userRepository,
                pdfProcessingService,
                elevenLabsService,
                sarvamService
        );
    }

    @Test
    @DisplayName("Splits text into sentence-aware chunks respecting size boundaries")
    void testTextChunking() {
        String longText = "First sentence here. Second sentence follows. Third sentence wraps up this section.";
        List<String> chunks = longFormSynthesisService.chunkText(longText, 35);

        assertNotNull(chunks);
        assertTrue(chunks.size() >= 2);
        for (String chunk : chunks) {
            assertTrue(chunk.length() <= 50);
        }
    }

    @Test
    @DisplayName("Submitting a long form synthesis job creates an in-memory job tracker")
    void testSubmitJob() throws Exception {
        TtsRequest request = new TtsRequest();
        request.setText("Paragraph one for document synthesis. Paragraph two continues the story.");
        request.setVoiceId("Joanna");
        request.setOutputFormat("mp3");

        when(pollyService.synthesizeSpeech(anyString(), anyString(), anyString(), anyMap()))
                .thenReturn(new ByteArrayInputStream(new byte[]{1, 2, 3, 4}));

        when(audioStorageService.storePdfAudio(anyLong(), any(), anyString()))
                .thenReturn(new AudioStorageService.StoredAudio("https://cdn-speakit-audio.mohitur.com/pdf-audio/doc_1.mp3", "pdf-audio/doc_1.mp3", 1024L, "audio/mpeg"));

        LongFormJobStatusDto job = longFormSynthesisService.submitJob(1L, PlanType.PRO, request);

        assertNotNull(job);
        assertNotNull(job.getJobId());
        assertTrue(job.getTotalChunks() >= 1);

        LongFormJobStatusDto status = longFormSynthesisService.getJobStatus(job.getJobId(), 1L);
        assertNotNull(status);
    }

    @Test
    @DisplayName("Submitting with documentToken claims staged text and consumes token")
    void testSubmitJobWithDocumentToken() throws Exception {
        TtsRequest request = new TtsRequest();
        request.setDocumentToken("token-123");
        request.setVoiceId("Joanna");
        request.setOutputFormat("mp3");

        PdfProcessingService.StagedDocument staged = new PdfProcessingService.StagedDocument(
                "token-123",
                1L,
                "Report.pdf",
                "Extracted text from staged document. Another sentence follows for synthesis.",
                10,
                2,
                15,
                System.currentTimeMillis()
        );

        when(pdfProcessingService.claimStagedDocument("token-123", 1L)).thenReturn(staged);
        when(pollyService.synthesizeSpeech(anyString(), anyString(), anyString(), anyMap()))
                .thenReturn(new ByteArrayInputStream(new byte[]{1, 2, 3, 4}));
        when(audioStorageService.storePdfAudio(anyLong(), any(), anyString()))
                .thenReturn(new AudioStorageService.StoredAudio("https://cdn-speakit-audio.mohitur.com/pdf-audio/doc_2.mp3", "pdf-audio/doc_2.mp3", 2048L, "audio/mpeg"));

        LongFormJobStatusDto job = longFormSynthesisService.submitJob(1L, PlanType.PRO, request);

        assertNotNull(job);
        assertEquals("Report.pdf", job.getSourceFileName());
        verify(pdfProcessingService).removeStagedDocument("token-123");
    }
}
