package com.speakit.tts.service;

import com.speakit.billing.entity.PlanType;
import com.speakit.shared.util.Sanitizer;
import com.speakit.tts.dto.LongFormJobStatusDto;
import com.speakit.tts.dto.TtsRequest;
import com.speakit.tts.entity.TtsHistory;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Enterprise Service for asynchronous long-form document and audiobook synthesis.
 * Chunks documents, synthesizes parts across configured providers, concatenates audio streams,
 * and caches to Cloudflare R2 / S3 storage.
 */
@Service
@Slf4j
public class LongFormSynthesisService {

    private final PollyService pollyService;
    private final AudioStorageService audioStorageService;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final UserRepository userRepository;
    private final PdfProcessingService pdfProcessingService;
    private final ElevenLabsService elevenLabsService;
    private final SarvamService sarvamService;

    private final Map<String, LongFormJobStatusDto> jobRegistry = new ConcurrentHashMap<>();

    @Autowired
    public LongFormSynthesisService(
            PollyService pollyService,
            AudioStorageService audioStorageService,
            TtsHistoryRepository ttsHistoryRepository,
            UserRepository userRepository,
            @Autowired(required = false) PdfProcessingService pdfProcessingService,
            @Autowired(required = false) ElevenLabsService elevenLabsService,
            @Autowired(required = false) SarvamService sarvamService
    ) {
        this.pollyService = pollyService;
        this.audioStorageService = audioStorageService;
        this.ttsHistoryRepository = ttsHistoryRepository;
        this.userRepository = userRepository;
        this.pdfProcessingService = pdfProcessingService;
        this.elevenLabsService = elevenLabsService;
        this.sarvamService = sarvamService;
    }

    public LongFormJobStatusDto submitJob(Long userId, PlanType planType, TtsRequest request) {
        String fullText;
        String sourceFileName = request.getSourceFileName();
        Integer estimatedDuration = null;

        // Check for staged document token
        if (request.getDocumentToken() != null && !request.getDocumentToken().isBlank() && pdfProcessingService != null) {
            var staged = pdfProcessingService.claimStagedDocument(request.getDocumentToken(), userId);
            if (staged == null) {
                throw new IllegalArgumentException("Invalid or expired document token. Please re-upload your document.");
            }
            fullText = staged.text();
            if (sourceFileName == null || sourceFileName.isBlank()) {
                sourceFileName = staged.fileName();
            }
            estimatedDuration = staged.estimatedDurationSeconds();
            pdfProcessingService.removeStagedDocument(request.getDocumentToken());
        } else {
            fullText = request.getText();
        }

        if (fullText == null || fullText.isBlank()) {
            throw new IllegalArgumentException("Text or documentToken is required for long-form synthesis.");
        }

        String sanitizedText = Sanitizer.sanitize(fullText);
        String voiceId = request.getVoiceId() != null ? request.getVoiceId() : "Joanna";
        String format = request.getOutputFormat() != null ? request.getOutputFormat() : "mp3";
        String title = request.getTitle() != null ? request.getTitle() : sourceFileName;

        List<String> chunks = chunkText(sanitizedText, 800);
        String jobId = UUID.randomUUID().toString();

        String snippet = sanitizedText.length() > 80 ? sanitizedText.substring(0, 80) + "..." : sanitizedText;
        if (sourceFileName != null && !sourceFileName.isBlank()) {
            snippet = "[" + sourceFileName + "] " + snippet;
        }

        LongFormJobStatusDto job = LongFormJobStatusDto.builder()
                .jobId(jobId)
                .userId(userId)
                .status("PROCESSING")
                .progressPercent(0)
                .totalChunks(chunks.size())
                .completedChunks(0)
                .totalCharacters(sanitizedText.length())
                .voiceId(voiceId)
                .sourceFileName(sourceFileName)
                .title(title)
                .estimatedDurationSeconds(estimatedDuration)
                .textSnippet(snippet)
                .createdAt(LocalDateTime.now())
                .build();

        jobRegistry.put(jobId, job);
        log.info("Queued long-form synthesis job: id={}, user={}, chunks={}, chars={}, source='{}'",
                jobId, userId, chunks.size(), sanitizedText.length(), sourceFileName);

        processJobAsync(jobId, userId, planType, voiceId, format, chunks, sanitizedText, request, sourceFileName, title);

        return job;
    }

    public LongFormJobStatusDto getJobStatus(String jobId, Long userId) {
        LongFormJobStatusDto job = jobRegistry.get(jobId);
        if (job != null && (userId == null || job.getUserId().equals(userId))) {
            return job;
        }
        return null;
    }

    @Async
    public void processJobAsync(
            String jobId,
            Long userId,
            PlanType planType,
            String voiceId,
            String format,
            List<String> chunks,
            String fullText,
            TtsRequest request,
            String sourceFileName,
            String title
    ) {
        LongFormJobStatusDto job = jobRegistry.get(jobId);
        if (job == null) return;

        try {
            ByteArrayOutputStream combinedAudio = new ByteArrayOutputStream();
            int completed = 0;

            for (String chunk : chunks) {
                InputStream chunkStream = synthesizeChunk(chunk, voiceId, format, request);
                if (chunkStream != null) {
                    chunkStream.transferTo(combinedAudio);
                }
                completed++;
                int progress = (int) (((double) completed / chunks.size()) * 100);
                job.setCompletedChunks(completed);
                job.setProgressPercent(progress);
            }

            byte[] finalBytes = combinedAudio.toByteArray();
            var storedAudio = audioStorageService.storePdfAudio(userId, finalBytes, format);

            job.setStatus("COMPLETED");
            job.setProgressPercent(100);
            job.setAudioUrl(storedAudio.url());
            job.setCompletedAt(LocalDateTime.now());

            // Save history record
            if (ttsHistoryRepository != null && userRepository != null) {
                userRepository.findById(userId).ifPresent(user -> {
                    String snippet = fullText.length() > 80 ? fullText.substring(0, 80) + "..." : fullText;
                    if (sourceFileName != null && !sourceFileName.isBlank()) {
                        snippet = "[" + sourceFileName + "] " + snippet;
                    }
                    TtsHistory history = TtsHistory.builder()
                            .user(user)
                            .voiceId(voiceId)
                            .voiceName(request != null && request.getVoiceName() != null ? request.getVoiceName() : voiceId)
                            .voiceType(determineVoiceType(voiceId, request))
                            .outputFormat(format)
                            .characterCount(fullText.length())
                            .textSnippet(snippet.length() > 100 ? snippet.substring(0, 97) + "..." : snippet)
                            .fullText(fullText)
                            .audioUrl(storedAudio.url())
                            .storageKey(storedAudio.storageKey())
                            .build();
                    ttsHistoryRepository.save(history);
                });

                // Atomically increment user's monthly TTS character usage ledger
                if (fullText != null && !fullText.isBlank()) {
                    userRepository.incrementTtsCharsUsed(userId, fullText.length(), java.time.LocalDate.now().withDayOfMonth(1));
                }
            }

            log.info("Completed long-form synthesis job: id={}, audioUrl={}", jobId, storedAudio.url());
        } catch (Exception e) {
            log.error("Failed processing long-form synthesis job: id={}", jobId, e);
            job.setStatus("FAILED");
            job.setErrorMessage(e.getMessage());
        }
    }

    private InputStream synthesizeChunk(String chunk, String voiceId, String format, TtsRequest request) {
        boolean isElevenLabs = (request != null && request.isElevenLabs()) ||
                (elevenLabsService != null && voiceId != null && elevenLabsService.getAvailableVoices().stream().anyMatch(v -> voiceId.equals(v.get("id"))));

        if (isElevenLabs && elevenLabsService != null) {
            String style = request != null ? request.getVoiceStyle() : null;
            return elevenLabsService.synthesizeSpeech(chunk, voiceId, style);
        }

        boolean isSarvam = (request != null && request.isSarvam()) ||
                (voiceId != null && (voiceId.toLowerCase().contains("bulbul") || voiceId.toLowerCase().contains("sarvam")));

        if (isSarvam && sarvamService != null) {
            String speaker = voiceId;
            String lang = request != null && request.getLanguageCode() != null ? request.getLanguageCode() : "hi-IN";
            if (voiceId != null && voiceId.contains(":")) {
                String[] parts = voiceId.split(":");
                speaker = parts[0];
                lang = parts[1];
            }
            Double pace = request != null ? request.getPace() : 1.0;
            Integer rate = request != null ? request.getSamplingRate() : null;
            return sarvamService.synthesizeSpeech(chunk, speaker, lang, pace, rate);
        }

        return pollyService.synthesizeSpeech(chunk, voiceId, format, Collections.emptyMap());
    }

    private String determineVoiceType(String voiceId, TtsRequest request) {
        if (request != null && request.isElevenLabs()) return "NATURAL";
        if (request != null && request.isSarvam()) return "INDIAN";
        if (voiceId != null && (voiceId.toLowerCase().contains("bulbul") || voiceId.toLowerCase().contains("sarvam"))) return "INDIAN";
        return "STANDARD";
    }

    public List<String> chunkText(String text, int targetChunkSize) {
        List<String> chunks = new ArrayList<>();
        if (text == null || text.isBlank()) return chunks;

        String[] sentences = text.split("(?<=[.!?])\\s+");
        StringBuilder currentChunk = new StringBuilder();

        for (String sentence : sentences) {
            if (currentChunk.length() + sentence.length() > targetChunkSize && currentChunk.length() > 0) {
                chunks.add(currentChunk.toString().trim());
                currentChunk = new StringBuilder();
            }
            if (currentChunk.length() > 0) {
                currentChunk.append(" ");
            }
            currentChunk.append(sentence);
        }

        if (currentChunk.length() > 0) {
            chunks.add(currentChunk.toString().trim());
        }

        return chunks;
    }
}
