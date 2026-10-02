package com.speakit.stt.service;

import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.stt.dto.SpeechToTextResult;
import com.speakit.stt.entity.SpeechToTextRequest;
import com.speakit.stt.exception.SttException;
import com.speakit.stt.provider.ElevenLabsSpeechToTextProvider;
import com.speakit.stt.provider.SarvamSpeechToTextProvider;
import com.speakit.stt.repository.SpeechToTextRequestRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.UUID;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;

@Service
@RequiredArgsConstructor
@Slf4j
public class SttService {

    private final SarvamSpeechToTextProvider sarvamProvider;
    private final ElevenLabsSpeechToTextProvider elevenLabsProvider;
    private final SpeechToTextRequestRepository sttRepository;
    private final UserRepository userRepository;
    private final SystemParameterService systemParameterService;

    // Bounded, auto-expiring deduplication cache (SEC-03 / CWE-770).
    // Fingerprints expire after the dedupe window so the map stays small at steady state.
    private final Cache<String, Long> messageFingerprints = Caffeine.newBuilder()
            .expireAfterWrite(java.time.Duration.ofMinutes(5))
            .maximumSize(50_000)
            .build();

    /**
     * Orchestrates the STT process with plan-aware provider selection and failover.
     */
    public SpeechToTextResult transcribe(MultipartFile multipartFile, String language, Long userId, String preferredProvider) {
        return transcribe(multipartFile, language, userId, preferredProvider, null);
    }

    public SpeechToTextResult transcribe(MultipartFile multipartFile, String language, Long userId, String preferredProvider, String mode) {
        Path tempFilePath = null;
        LocalDateTime startTime = LocalDateTime.now();
        
        try {
            // 1. Create temporary file
            tempFilePath = Files.createTempFile("stt_", "_" + UUID.randomUUID());
            multipartFile.transferTo(tempFilePath.toFile());
            File audioFile = tempFilePath.toFile();

            // 2. Message Fingerprinting (Anti-Spam)
            // Caffeine Cache does not expose putIfAbsent; we use getIfPresent + put.
            // The cache auto-expires entries after the configured window (5 min),
            // so the map stays bounded even under sustained traffic (SEC-03).
            String fingerprint = generateFileFingerprint(audioFile, userId);
            long now = System.currentTimeMillis();
            
            long dedupeWindow = systemParameterService.getLongParameter("STT_DEDUPE_WINDOW_MS", 60000L);
            Long previousTime = messageFingerprints.getIfPresent(fingerprint);
            
            if (previousTime != null && (now - previousTime < dedupeWindow)) {
                log.warn("Duplicate STT request detected from user {}. Blocking.", userId);
                throw new SttException("Duplicate request. Please wait before transcribing the same file again.");
            }
            messageFingerprints.put(fingerprint, now);

            // 3. Determine Attempt Order
            // Default to Sarvam (Indian dialects), fallback to ElevenLabs
            String firstChoice = (preferredProvider != null && preferredProvider.equalsIgnoreCase("ELEVEN_LABS")) 
                    ? "ELEVEN_LABS" 
                    : "SARVAM";

            SpeechToTextResult result = null;
            try {
                log.info("Attempting STT with primary choice: {} for user {} mode: {}", firstChoice, userId, mode);
                result = attemptTranscription(firstChoice, audioFile, language, mode);
            } catch (Exception e) {
                String fallback = firstChoice.equals("SARVAM") ? "ELEVEN_LABS" : "SARVAM";
                log.warn("{} failed, attempting fallback to {}: {}", firstChoice, fallback, e.getMessage());
                result = attemptTranscription(fallback, audioFile, language, mode);
            }

            // 4. Persistence (Full History & Audit)
            String filename = multipartFile != null ? multipartFile.getOriginalFilename() : "audio_memo";
            saveMetadata(userId, result, multipartFile.getSize(), "SUCCESS", null, startTime, mode, filename);
            
            return result;

        } catch (IOException e) {
            log.error("Internal IO error during STT processing", e);
            throw new SttException("Failed to process audio file internally.");
        } catch (Exception e) {
            log.error("STT processing failed for user {}", userId, e);
            String filename = multipartFile != null ? multipartFile.getOriginalFilename() : "audio_memo";
            saveMetadata(userId, null, multipartFile.getSize(), "FAILED", e.getMessage(), startTime, mode, filename);
            throw new SttException("Speech transcription failed: " + e.getMessage());
        } finally {
            // 5. Guaranteed deletion
            if (tempFilePath != null) {
                try {
                    Files.deleteIfExists(tempFilePath);
                    log.debug("Temporary STT file deleted: {}", tempFilePath);
                } catch (IOException e) {
                    log.warn("Failed to delete temporary STT file: {}", tempFilePath);
                }
            }
        }
    }

    private SpeechToTextResult attemptTranscription(String providerName, File file, String language, String mode) {
        if ("ELEVEN_LABS".equals(providerName)) {
            return elevenLabsProvider.transcribe(file, language);
        }
        if (mode != null && !mode.isBlank()) {
            return sarvamProvider.transcribe(file, language, mode);
        }
        return sarvamProvider.transcribe(file, language);
    }

    private String generateFileFingerprint(File file, Long userId) {
        try {
            java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
            digest.update(userId.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8));
            
            try (java.io.FileInputStream fis = new java.io.FileInputStream(file)) {
                byte[] buffer = new byte[1024 * 1024];
                int read = fis.read(buffer);
                if (read != -1) {
                    digest.update(buffer, 0, read);
                }
            }
            return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(digest.digest());
        } catch (Exception e) {
            return userId + "_" + file.length() + "_" + file.getName();
        }
    }

    private void saveMetadata(Long userId, SpeechToTextResult result, long sizeBytes, String status, String failureReason, LocalDateTime startTime, String mode, String filename) {
        try {
            User user = userRepository.getReferenceById(userId);
            SpeechToTextRequest request = SpeechToTextRequest.builder()
                    .user(user)
                    .provider(result != null ? result.getProvider() : "UNKNOWN")
                    .audioSizeBytes(sizeBytes)
                    .audioDurationSeconds(result != null && result.getDuration() != null ? result.getDuration().intValue() : 0)
                    .language(result != null ? result.getLanguage() : null)
                    .transcriptLength(result != null && result.getTranscript() != null ? result.getTranscript().length() : 0)
                    .transcript(result != null ? result.getTranscript() : null)
                    .transliteration(result != null ? result.getTransliteration() : null)
                    .processingMode(mode != null ? mode : "transcribe")
                    .originalFilename(filename)
                    .status(status)
                    .failureReason(failureReason)
                    .completedAt(LocalDateTime.now())
                    .build();
            sttRepository.save(request);
            log.info("Saved STT history record: user={} provider={} mode={} length={}",
                    userId, request.getProvider(), request.getProcessingMode(), request.getTranscriptLength());
        } catch (Exception e) {
            log.warn("Failed to save STT metadata audit log", e);
        }
    }
}
