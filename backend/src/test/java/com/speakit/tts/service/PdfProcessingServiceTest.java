package com.speakit.tts.service;

import com.speakit.billing.entity.PlanType;
import com.speakit.billing.service.SubscriptionService;
import com.speakit.tts.dto.DocumentAnalysisDto;
import com.speakit.tts.validator.PdfDocumentValidator;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;

import java.io.ByteArrayOutputStream;
import java.io.IOException;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PdfProcessingServiceTest {

    @Mock
    private SubscriptionService subscriptionService;

    private PdfDocumentValidator pdfDocumentValidator;
    private PdfProcessingService pdfProcessingService;

    @BeforeEach
    void setUp() {
        pdfDocumentValidator = new PdfDocumentValidator(subscriptionService);
        pdfProcessingService = new PdfProcessingService(pdfDocumentValidator, subscriptionService);

        // Default plan limits
        lenient().when(subscriptionService.getPdfMaxFileSizeBytes(any())).thenReturn(25 * 1024 * 1024L);
        lenient().when(subscriptionService.getPdfMaxPages(any())).thenReturn(50);
        lenient().when(subscriptionService.getPdfMaxWords(any())).thenReturn(25000);
    }

    private byte[] createTestPdf(int pageCount, String text) throws IOException {
        try (PDDocument doc = new PDDocument()) {
            for (int i = 0; i < pageCount; i++) {
                PDPage page = new PDPage();
                doc.addPage(page);
                if (text != null && !text.isBlank()) {
                    try (PDPageContentStream cs = new PDPageContentStream(doc, page)) {
                        cs.beginText();
                        cs.setFont(new PDType1Font(Standard14Fonts.FontName.HELVETICA), 12);
                        cs.newLineAtOffset(50, 700);
                        cs.showText(text);
                        cs.endText();
                    }
                }
            }
            ByteArrayOutputStream baos = new ByteArrayOutputStream();
            doc.save(baos);
            return baos.toByteArray();
        }
    }

    @Test
    @DisplayName("Successfully validates, extracts text and stages a valid multi-page PDF")
    void testAnalyzeAndStage_ValidPdf() throws Exception {
        byte[] pdfBytes = createTestPdf(3, "The quick brown fox jumps over the lazy dog.");
        MockMultipartFile file = new MockMultipartFile("file", "chapter1.pdf", "application/pdf", pdfBytes);

        DocumentAnalysisDto result = pdfProcessingService.analyzeAndStage(file, 42L, PlanType.PRO);

        assertNotNull(result);
        assertNotNull(result.getDocumentToken());
        assertEquals("chapter1.pdf", result.getFileName());
        assertEquals(3, result.getPageCount());
        assertTrue(result.getWordCount() > 0);
        assertEquals("READY", result.getValidationStatus());

        // Verify retrieval of staged document
        var staged = pdfProcessingService.claimStagedDocument(result.getDocumentToken(), 42L);
        assertNotNull(staged);
        assertEquals(42L, staged.userId());
        assertTrue(staged.text().contains("fox"));
    }

    @Test
    @DisplayName("Rejects image-only / empty PDFs with no extractable text")
    void testAnalyzeAndStage_ImageOnlyPdf() throws Exception {
        byte[] pdfBytes = createTestPdf(1, ""); // 1 page, zero text
        MockMultipartFile file = new MockMultipartFile("file", "scanned.pdf", "application/pdf", pdfBytes);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                pdfProcessingService.analyzeAndStage(file, 42L, PlanType.PRO)
        );
        assertTrue(ex.getMessage().contains("No extractable text was found"));
    }

    @Test
    @DisplayName("Rejects document when page count exceeds plan limit")
    void testAnalyzeAndStage_PageLimitExceeded() throws Exception {
        when(subscriptionService.getPdfMaxPages(PlanType.FREE)).thenReturn(2);

        byte[] pdfBytes = createTestPdf(5, "Hello world test document.");
        MockMultipartFile file = new MockMultipartFile("file", "large.pdf", "application/pdf", pdfBytes);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                pdfProcessingService.analyzeAndStage(file, 42L, PlanType.FREE)
        );
        assertTrue(ex.getMessage().contains("allows a maximum of 2 pages"));
    }

    @Test
    @DisplayName("Rejects document when word count exceeds plan limit")
    void testAnalyzeAndStage_WordLimitExceeded() throws Exception {
        when(subscriptionService.getPdfMaxWords(PlanType.FREE)).thenReturn(3);

        byte[] pdfBytes = createTestPdf(1, "One two three four five six seven eight nine ten.");
        MockMultipartFile file = new MockMultipartFile("file", "long_text.pdf", "application/pdf", pdfBytes);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                pdfProcessingService.analyzeAndStage(file, 42L, PlanType.FREE)
        );
        assertTrue(ex.getMessage().contains("allows a maximum of 3 words"));
    }

    @Test
    @DisplayName("Rejects file with invalid signature (not a real PDF)")
    void testValidation_InvalidMagicBytes() {
        byte[] fakeBytes = "This is just a text file renamed to .pdf".getBytes();
        MockMultipartFile file = new MockMultipartFile("file", "fake.pdf", "application/pdf", fakeBytes);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                pdfProcessingService.analyzeAndStage(file, 42L, PlanType.PRO)
        );
        assertTrue(ex.getMessage().contains("Invalid PDF signature"));
    }

    @Test
    @DisplayName("Rejects file with double extension")
    void testValidation_DoubleExtension() {
        byte[] bytes = new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D};
        MockMultipartFile file = new MockMultipartFile("file", "trojan.pdf.exe", "application/pdf", bytes);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                pdfProcessingService.analyzeAndStage(file, 42L, PlanType.PRO)
        );
        assertTrue(ex.getMessage().contains("Double extensions are forbidden"));
    }

    @Test
    @DisplayName("Rejects file exceeding max file size limit")
    void testValidation_FileSizeExceeded() {
        when(subscriptionService.getPdfMaxFileSizeBytes(PlanType.FREE)).thenReturn(100L); // 100 bytes max
        byte[] bytes = new byte[200];
        bytes[0] = 0x25; bytes[1] = 0x50; bytes[2] = 0x44; bytes[3] = 0x46; bytes[4] = 0x2D;

        MockMultipartFile file = new MockMultipartFile("file", "doc.pdf", "application/pdf", bytes);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                pdfProcessingService.analyzeAndStage(file, 42L, PlanType.FREE)
        );
        assertTrue(ex.getMessage().contains("exceeds the maximum permitted file size"));
    }
}
