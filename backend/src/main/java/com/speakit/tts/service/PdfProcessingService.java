package com.speakit.tts.service;

import com.speakit.billing.entity.PlanType;
import com.speakit.billing.service.SubscriptionService;
import com.speakit.tts.dto.DocumentAnalysisDto;
import com.speakit.tts.validator.PdfDocumentValidator;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.apache.pdfbox.Loader;
import org.apache.pdfbox.io.RandomAccessReadBuffer;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Enterprise Service for PDF parsing, text extraction, plan validation,
 * reading duration estimation, and staged document token management.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class PdfProcessingService {

    private final PdfDocumentValidator pdfDocumentValidator;
    private final SubscriptionService subscriptionService;

    public record StagedDocument(
            String token,
            Long userId,
            String fileName,
            String text,
            int wordCount,
            int pageCount,
            int estimatedDurationSeconds,
            long createdAt
    ) {}

    private final Map<String, StagedDocument> stagedCache = new ConcurrentHashMap<>();
    private static final long STAGED_DOC_TTL_MS = 30 * 60 * 1000L; // 30 minutes

    /**
     * Validates and analyzes an uploaded PDF document, extracting text and computing metrics.
     */
    public DocumentAnalysisDto analyzeAndStage(MultipartFile file, Long userId, PlanType planType) {
        // 1. Structural & Security Validation
        pdfDocumentValidator.validate(file, planType);

        String originalFilename = file.getOriginalFilename();

        try (InputStream is = file.getInputStream();
             RandomAccessReadBuffer buffer = new RandomAccessReadBuffer(is);
             PDDocument document = Loader.loadPDF(buffer)) {

            // 2. Encryption / Password Check
            if (document.isEncrypted()) {
                throw new IllegalArgumentException("This PDF is password-protected. Please upload an unlocked PDF.");
            }

            // 3. Page Count Validation
            int pageCount = document.getNumberOfPages();
            if (pageCount == 0) {
                throw new IllegalArgumentException("The uploaded PDF is empty and contains no pages.");
            }

            int maxPages = subscriptionService.getPdfMaxPages(planType);
            if (pageCount > maxPages) {
                throw new IllegalArgumentException(String.format(
                        "This document contains %d pages. Your current %s plan allows a maximum of %d pages.",
                        pageCount, planType != null ? planType.name() : "FREE", maxPages));
            }

            // 4. Text Extraction
            PDFTextStripper stripper = new PDFTextStripper();
            stripper.setSortByPosition(true);
            String rawText = stripper.getText(document);

            String normalizedText = normalizeExtractedText(rawText);
            if (normalizedText.isBlank()) {
                throw new IllegalArgumentException("No extractable text was found in this document. Scanned or image-only PDFs require OCR, which is not supported.");
            }

            // 5. Word Count Validation
            int wordCount = countWords(normalizedText);
            if (wordCount == 0) {
                throw new IllegalArgumentException("No extractable text was found in this document. Scanned or image-only PDFs require OCR, which is not supported.");
            }

            int maxWords = subscriptionService.getPdfMaxWords(planType);
            if (wordCount > maxWords) {
                throw new IllegalArgumentException(String.format(
                        "This document contains %d words. Your current %s plan allows a maximum of %d words.",
                        wordCount, planType != null ? planType.name() : "FREE", maxWords));
            }

            // 6. Estimated Audio Duration (at standard ~150 words per minute)
            int estimatedDurationSeconds = (int) Math.round(((double) wordCount / 150.0) * 60.0);
            String formattedDuration = formatDuration(estimatedDurationSeconds);

            // 7. Secure Staging Token
            String token = UUID.randomUUID().toString();
            stagedCache.put(token, new StagedDocument(
                    token,
                    userId,
                    originalFilename,
                    normalizedText,
                    wordCount,
                    pageCount,
                    estimatedDurationSeconds,
                    System.currentTimeMillis()
            ));

            log.info("Successfully analyzed and staged PDF: user={}, file='{}', pages={}, words={}, estDuration={}",
                    userId, originalFilename, pageCount, wordCount, formattedDuration);

            return DocumentAnalysisDto.builder()
                    .documentToken(token)
                    .fileName(originalFilename)
                    .fileSizeBytes(file.getSize())
                    .pageCount(pageCount)
                    .wordCount(wordCount)
                    .characterCount(normalizedText.length())
                    .estimatedDurationSeconds(estimatedDurationSeconds)
                    .estimatedDurationFormatted(formattedDuration)
                    .validationStatus("READY")
                    .warnings(Collections.emptyList())
                    .build();

        } catch (IllegalArgumentException e) {
            throw e;
        } catch (IOException e) {
            log.error("Failed to parse PDF document: {}", originalFilename, e);
            throw new IllegalArgumentException("The uploaded document is corrupted or cannot be processed.");
        }
    }

    /**
     * Retrieves and claims a staged document by token, verifying user ownership.
     */
    public StagedDocument claimStagedDocument(String token, Long userId) {
        if (token == null || token.isBlank()) return null;
        StagedDocument doc = stagedCache.get(token);
        if (doc != null && (userId == null || doc.userId().equals(userId))) {
            return doc;
        }
        return null;
    }

    /**
     * Purges a staged document from the cache once job synthesis has begun.
     */
    public void removeStagedDocument(String token) {
        if (token != null) {
            stagedCache.remove(token);
        }
    }

    public String normalizeExtractedText(String text) {
        if (text == null) return "";
        return text
                .replaceAll("\\r\\n|\\r", "\n")
                .replaceAll("[ \\t]+", " ")
                .replaceAll("\\n{3,}", "\n\n")
                .trim();
    }

    public int countWords(String text) {
        if (text == null || text.isBlank()) return 0;
        String trimmed = text.trim();
        return trimmed.split("\\s+").length;
    }

    public String formatDuration(int totalSeconds) {
        if (totalSeconds < 60) {
            return totalSeconds + "s";
        }
        int hours = totalSeconds / 3600;
        int minutes = (totalSeconds % 3600) / 60;
        if (hours > 0) {
            return String.format("%dh %02dm", hours, minutes);
        } else {
            return String.format("%dm", minutes);
        }
    }

    /**
     * Evicts expired staged documents every 5 minutes.
     */
    @Scheduled(fixedRate = 300_000)
    public void cleanupExpiredStagedDocuments() {
        long now = System.currentTimeMillis();
        stagedCache.entrySet().removeIf(entry -> (now - entry.getValue().createdAt()) > STAGED_DOC_TTL_MS);
    }
}
