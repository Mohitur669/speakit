package com.stt.service;

import com.tts.entity.User;
import com.tts.repository.UserRepository;
import com.tts.service.SystemParameterService;
import com.stt.dto.SpeechToTextResult;
import com.stt.entity.SpeechToTextRequest;
import com.stt.exception.SttException;
import com.stt.provider.ElevenLabsSpeechToTextProvider;
import com.stt.provider.SarvamSpeechToTextProvider;
import com.stt.repository.SpeechToTextRequestRepository;
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
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
@Slf4j
public class SttService {

    private final SarvamSpeechToTextProvider sarvamProvider;
    private final ElevenLabsSpeechToTextProvider elevenLabsProvider;
    private final SpeechToTextRequestRepository sttRepository;
    private final UserRepository userRepository;
    private final SystemParameterService systemParameterService;

    // Memory-efficient deduplication cache (Hashed Content -> Timestamp)
    private final ConcurrentHashMap<String, Long> messageFingerprints = new ConcurrentHashMap<>();

    /**
     * Orchestrates the STT process with plan-aware provider selection and failover.
     */
    @Transactional
    public SpeechToTextResult transcribe(MultipartFile multipartFile, String language, Long userId, String preferredProvider) {
        Path tempFilePath = null;
        LocalDateTime startTime = LocalDateTime.now();
        
        try {
            // 1. Create temporary file
            tempFilePath = Files.createTempFile("stt_", "_" + UUID.randomUUID());
            multipartFile.transferTo(tempFilePath.toFile());
            File audioFile = tempFilePath.toFile();

            // 2. Message Fingerprinting (Anti-Spam - Atomic)
            String fingerprint = generateFileFingerprint(audioFile, userId);
            long now = System.currentTimeMillis();
            
            long dedupeWindow = Long.parseLong(systemParameterService.getLiveParameter("STT_DEDUPE_WINDOW_MS", "60000"));
            Long previousTime = messageFingerprints.putIfAbsent(fingerprint, now);
            
            if (previousTime != null && (now - previousTime < dedupeWindow)) {
                log.warn("Duplicate STT request detected from user {}. Blocking.", userId);
                throw new SttException("Duplicate request. Please wait before transcribing the same file again.");
            }

            // 3. Determine Attempt Order
            // Default to Sarvam (Indian dialects), fallback to ElevenLabs
            String firstChoice = (preferredProvider != null && preferredProvider.equalsIgnoreCase("ELEVEN_LABS")) 
                    ? "ELEVEN_LABS" 
                    : "SARVAM";

            SpeechToTextResult result = null;
            try {
                log.info("Attempting STT with primary choice: {} for user {}", firstChoice, userId);
                result = attemptTranscription(firstChoice, audioFile, language);
            } catch (Exception e) {
                String fallback = firstChoice.equals("SARVAM") ? "ELEVEN_LABS" : "SARVAM";
                log.warn("{} failed, attempting fallback to {}: {}", firstChoice, fallback, e.getMessage());
                result = attemptTranscription(fallback, audioFile, language);
            }

            // 4. Persistence (Metadata only)
            saveMetadata(userId, result, multipartFile.getSize(), "SUCCESS", null, startTime);
            
            return result;

        } catch (IOException e) {
            log.error("Internal IO error during STT processing", e);
            throw new SttException("Failed to process audio file internally.");
        } catch (Exception e) {
            log.error("STT processing failed for user {}", userId, e);
            saveMetadata(userId, null, multipartFile.getSize(), "FAILED", e.getMessage(), startTime);
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

    private SpeechToTextResult attemptTranscription(String providerName, File file, String language) {
        if ("ELEVEN_LABS".equals(providerName)) {
            return elevenLabsProvider.transcribe(file, language);
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

    private void saveMetadata(Long userId, SpeechToTextResult result, long sizeBytes, String status, String failureReason, LocalDateTime startTime) {
        try {
            User user = userRepository.getReferenceById(userId);
            SpeechToTextRequest request = SpeechToTextRequest.builder()
                    .user(user)
                    .provider(result != null ? result.getProvider() : "UNKNOWN")
                    .audioSizeBytes(sizeBytes)
                    .audioDurationSeconds(result != null && result.getDuration() != null ? result.getDuration().intValue() : 0)
                    .language(result != null ? result.getLanguage() : null)
                    .transcriptLength(result != null && result.getTranscript() != null ? result.getTranscript().length() : 0)
                    .status(status)
                    .failureReason(failureReason)
                    .completedAt(LocalDateTime.now())
                    .build();
            sttRepository.save(request);
        } catch (Exception e) {
            log.warn("Failed to save STT metadata audit log", e);
        }
    }
}
