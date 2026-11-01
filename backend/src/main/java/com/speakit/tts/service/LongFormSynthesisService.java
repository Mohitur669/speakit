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
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Enterprise Service for asynchronous long-form document and audiobook synthesis.
 * Chunks documents, synthesizes parts, concatenates audio streams, and caches to Cloudflare R2.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LongFormSynthesisService {

    private final PollyService pollyService;
    private final AudioStorageService audioStorageService;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final UserRepository userRepository;

    private final Map<String, LongFormJobStatusDto> jobRegistry = new ConcurrentHashMap<>();

    public LongFormJobStatusDto submitJob(Long userId, PlanType planType, TtsRequest request) {
        String sanitizedText = Sanitizer.sanitize(request.getText());
        String voiceId = request.getVoiceId() != null ? request.getVoiceId() : "Joanna";
        String format = request.getOutputFormat() != null ? request.getOutputFormat() : "mp3";

        List<String> chunks = chunkText(sanitizedText, 800);
        String jobId = UUID.randomUUID().toString();

        LongFormJobStatusDto job = LongFormJobStatusDto.builder()
                .jobId(jobId)
                .userId(userId)
                .status("PROCESSING")
                .progressPercent(0)
                .totalChunks(chunks.size())
                .completedChunks(0)
                .totalCharacters(sanitizedText.length())
                .voiceId(voiceId)
                .textSnippet(sanitizedText.length() > 80 ? sanitizedText.substring(0, 80) + "..." : sanitizedText)
                .createdAt(LocalDateTime.now())
                .build();

        jobRegistry.put(jobId, job);
        log.info("Queued long-form synthesis job: id={}, user={}, chunks={}, chars={}",
                jobId, userId, chunks.size(), sanitizedText.length());

        processJobAsync(jobId, userId, planType, voiceId, format, chunks, sanitizedText);

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
    public void processJobAsync(String jobId, Long userId, PlanType planType, String voiceId, String format, List<String> chunks, String fullText) {
        LongFormJobStatusDto job = jobRegistry.get(jobId);
        if (job == null) return;

        try {
            ByteArrayOutputStream combinedAudio = new ByteArrayOutputStream();
            int completed = 0;

            for (String chunk : chunks) {
                InputStream chunkStream = pollyService.synthesizeSpeech(chunk, voiceId, format, Collections.emptyMap());
                if (chunkStream != null) {
                    chunkStream.transferTo(combinedAudio);
                }
                completed++;
                int progress = (int) (((double) completed / chunks.size()) * 100);
                job.setCompletedChunks(completed);
                job.setProgressPercent(progress);
            }

            byte[] finalBytes = combinedAudio.toByteArray();
            var storedAudio = audioStorageService.storeAudio(userId, finalBytes, format);

            job.setStatus("COMPLETED");
            job.setProgressPercent(100);
            job.setAudioUrl(storedAudio.url());
            job.setCompletedAt(LocalDateTime.now());

            // Save history record
            if (ttsHistoryRepository != null && userRepository != null) {
                userRepository.findById(userId).ifPresent(user -> {
                    TtsHistory history = TtsHistory.builder()
                            .user(user)
                            .voiceId(voiceId)
                            .voiceName(voiceId)
                            .voiceType("STANDARD")
                            .outputFormat(format)
                            .characterCount(fullText.length())
                            .textSnippet(fullText.length() > 80 ? fullText.substring(0, 80) + "..." : fullText)
                            .fullText(fullText)
                            .audioUrl(storedAudio.url())
                            .storageKey(storedAudio.storageKey())
                            .build();
                    ttsHistoryRepository.save(history);
                });
            }

            log.info("Completed long-form synthesis job: id={}, audioUrl={}", jobId, storedAudio.url());
        } catch (Exception e) {
            log.error("Failed processing long-form synthesis job: id={}", jobId, e);
            job.setStatus("FAILED");
            job.setErrorMessage(e.getMessage());
        }
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
