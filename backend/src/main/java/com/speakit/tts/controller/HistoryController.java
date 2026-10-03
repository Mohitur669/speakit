package com.speakit.tts.controller;

import com.speakit.stt.entity.SpeechToTextRequest;
import com.speakit.stt.repository.SpeechToTextRequestRepository;
import com.speakit.tts.dto.TtsHistoryDto;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.tts.service.AudioStorageService;
import com.speakit.tts.service.PollyService;
import com.speakit.tts.service.ElevenLabsService;
import com.speakit.tts.service.SarvamService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.InputStreamResource;
import org.springframework.data.web.PagedModel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.io.InputStream;
import java.net.URI;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * REST controller for retrieving user-specific analytics, audio streaming, and history management.
 */
@RestController
@RequestMapping("/api/history")
@RequiredArgsConstructor
@Slf4j
public class HistoryController {

    private final TtsHistoryRepository ttsHistoryRepository;
    private final SpeechToTextRequestRepository speechToTextRequestRepository;
    private final AudioStorageService audioStorageService;
    private final PollyService pollyService;
    private final ElevenLabsService elevenLabsService;
    private final SarvamService sarvamService;

    @GetMapping
    public ResponseEntity<PagedModel<TtsHistoryDto>> getHistory(
            HttpServletRequest request,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "ALL") String type
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String filterType = (type != null) ? type.trim().toUpperCase() : "ALL";

        if ("TTS".equals(filterType) || "TRANSLATE".equals(filterType)) {
            Page<TtsHistoryDto> historyPage = ttsHistoryRepository
                    .findRecentHistoryByUserId(userId, PageRequest.of(page, size))
                    .map(this::mapTtsToDto);
            return ResponseEntity.ok(new PagedModel<>(historyPage));
        }

        if ("LIVE".equals(filterType) || "LIVE_CHAT".equals(filterType)) {
            int fetchLimit = (page + 1) * size * 2;
            Page<SpeechToTextRequest> sttRecent = speechToTextRequestRepository
                    .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(0, Math.max(fetchLimit, 50)));
            List<TtsHistoryDto> liveList = sttRecent.getContent().stream()
                    .filter(this::isLiveSession)
                    .map(this::mapSttToDto)
                    .toList();
            int start = Math.min(page * size, liveList.size());
            int end = Math.min(start + size, liveList.size());
            List<TtsHistoryDto> pagedItems = (start < end) ? liveList.subList(start, end) : Collections.emptyList();
            Page<TtsHistoryDto> livePage = new PageImpl<>(pagedItems, PageRequest.of(page, size), liveList.size());
            return ResponseEntity.ok(new PagedModel<>(livePage));
        }

        if ("STT".equals(filterType) || "TRANSCRIBE".equals(filterType)) {
            int fetchLimit = (page + 1) * size * 2;
            Page<SpeechToTextRequest> sttRecent = speechToTextRequestRepository
                    .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(0, Math.max(fetchLimit, 50)));
            List<TtsHistoryDto> sttList = sttRecent.getContent().stream()
                    .filter(s -> !isLiveSession(s))
                    .map(this::mapSttToDto)
                    .toList();
            int start = Math.min(page * size, sttList.size());
            int end = Math.min(start + size, sttList.size());
            List<TtsHistoryDto> pagedItems = (start < end) ? sttList.subList(start, end) : Collections.emptyList();
            Page<TtsHistoryDto> sttPage = new PageImpl<>(pagedItems, PageRequest.of(page, size), sttList.size());
            return ResponseEntity.ok(new PagedModel<>(sttPage));
        }

        // "ALL": Merge both TTS and STT records sorted by createdAt DESC
        int fetchLimit = Math.max((page + 1) * size * 2, 50);
        Page<com.speakit.tts.entity.TtsHistory> ttsRecent = ttsHistoryRepository
                .findRecentHistoryByUserId(userId, PageRequest.of(0, fetchLimit));
        Page<SpeechToTextRequest> sttRecent = speechToTextRequestRepository
                .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(0, fetchLimit));

        List<TtsHistoryDto> combined = new ArrayList<>();
        ttsRecent.forEach(history -> combined.add(mapTtsToDto(history)));
        sttRecent.forEach(stt -> combined.add(mapSttToDto(stt)));

        combined.sort((a, b) -> {
            if (a.getCreatedAt() == null && b.getCreatedAt() == null) return 0;
            if (a.getCreatedAt() == null) return 1;
            if (b.getCreatedAt() == null) return -1;
            return b.getCreatedAt().compareTo(a.getCreatedAt());
        });

        int start = Math.min(page * size, combined.size());
        int end = Math.min(start + size, combined.size());
        List<TtsHistoryDto> pagedItems = (start < end) ? combined.subList(start, end) : Collections.emptyList();

        long totalElements = ttsRecent.getTotalElements() + sttRecent.getTotalElements();
        Page<TtsHistoryDto> unifiedPage = new PageImpl<>(pagedItems, PageRequest.of(page, size), totalElements);

        return ResponseEntity.ok(new PagedModel<>(unifiedPage));
    }

    private boolean isLiveSession(SpeechToTextRequest stt) {
        if (stt == null) return false;
        if ("conversation".equalsIgnoreCase(stt.getProcessingMode())) return true;
        if ("LIVE".equalsIgnoreCase(stt.getProvider())) return true;
        String title = stt.getOriginalFilename();
        if (title != null && (title.toLowerCase().contains("live conversation") || title.toLowerCase().contains("live session"))) {
            return true;
        }
        String transcript = stt.getTranscript();
        if (transcript != null && (transcript.contains("↳ [") || transcript.contains("[Speaker") || transcript.contains("[Person"))) {
            return true;
        }
        return false;
    }

    private TtsHistoryDto mapTtsToDto(com.speakit.tts.entity.TtsHistory history) {
        String resolvedAudioUrl = history.getAudioUrl();
        if (history.getStorageKey() != null) {
            resolvedAudioUrl = audioStorageService.buildPublicUrl(history.getStorageKey());
        }
        return TtsHistoryDto.builder()
                .id(history.getId())
                .voiceId(history.getVoiceId())
                .voiceName(history.getVoiceName())
                .voiceType(history.getVoiceType())
                .outputFormat(history.getOutputFormat())
                .characterCount(history.getCharacterCount())
                .textSnippet(history.getTextSnippet())
                .fullText(history.getFullText() != null ? history.getFullText() : history.getTextSnippet())
                .audioUrl(resolvedAudioUrl)
                .createdAt(history.getCreatedAt())
                .engineType("TTS")
                .status("SUCCESS")
                .build();
    }

    private TtsHistoryDto mapSttToDto(SpeechToTextRequest stt) {
        String transcript = stt.getTranscript() != null ? stt.getTranscript().trim() : "";
        String title = stt.getOriginalFilename() != null ? stt.getOriginalFilename() : "Audio Transcription";

        String snippet = transcript;
        if (snippet.length() > 75) {
            snippet = snippet.substring(0, 75) + "...";
        }
        if (snippet.isEmpty()) {
            snippet = title;
        }

        boolean live = isLiveSession(stt);
        String displayName = title;
        if (!live) {
            if ("SARVAM".equalsIgnoreCase(stt.getProvider())) {
                displayName = "Sarvam Saaras";
            } else if (stt.getProvider() != null) {
                displayName = stt.getProvider();
            }
        }

        int charCount = stt.getTranscriptLength() != null && stt.getTranscriptLength() > 0
                ? stt.getTranscriptLength()
                : transcript.length();

        return TtsHistoryDto.builder()
                .id(stt.getId())
                .voiceId(stt.getLanguage() != null ? stt.getLanguage() : "hi-IN")
                .voiceName(displayName)
                .voiceType(live ? "LIVE" : "STT")
                .outputFormat("wav")
                .characterCount(charCount)
                .textSnippet(snippet)
                .fullText(transcript)
                .audioUrl(null)
                .createdAt(stt.getCreatedAt())
                .engineType(live ? "LIVE" : "STT")
                .transliteration(stt.getTransliteration())
                .mode(stt.getProcessingMode() != null ? stt.getProcessingMode() : "transcribe")
                .filename(title)
                .status(stt.getStatus() != null ? stt.getStatus() : "SUCCESS")
                .build();
    }

    /**
     * Streams or redirects to the audio file for a given history item.
     * Enforces ownership authorization before streaming.
     */
    @GetMapping("/{id}/audio")
    public ResponseEntity<?> getHistoryAudio(
            HttpServletRequest request,
            @PathVariable Long id
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        var historyOpt = ttsHistoryRepository.findByIdAndUserId(id, userId);
        if (historyOpt.isEmpty()) {
            return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
        }

        var history = historyOpt.get();
        String storageKey = history.getStorageKey();
        String audioUrl = history.getAudioUrl();

        // 1. If storageKey exists, always build and redirect to latest canonical Cloudflare R2 CDN URL
        if (storageKey != null) {
            String cdnUrl = audioStorageService.buildPublicUrl(storageKey);
            if (cdnUrl != null && cdnUrl.startsWith("http")) {
                return ResponseEntity.status(HttpStatus.FOUND)
                        .location(URI.create(cdnUrl))
                        .build();
            }
        } else if (audioUrl != null && audioUrl.startsWith("http") && !audioUrl.contains("speakit.com")) {
            return ResponseEntity.status(HttpStatus.FOUND)
                    .location(URI.create(audioUrl))
                    .build();
        }

        // 2. Stream audio from storage (R2 or local fallback disk)
        try {
            InputStream audioStream = audioStorageService.getAudioInputStream(storageKey, audioUrl);
            if (audioStream == null) {
                // Self-Healing On-Demand Synthesis Fallback for legacy history items without storage
                audioStream = resynthesizeAudio(history);
            }
            if (audioStream == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND).build();
            }

            MediaType mediaType = getMediaType(history.getOutputFormat());
            return ResponseEntity.ok()
                    .contentType(mediaType)
                    .header(HttpHeaders.CACHE_CONTROL, "public, max-age=31536000, immutable")
                    .body(new InputStreamResource(audioStream));
        } catch (Exception e) {
            log.error("Failed to stream audio for history ID {} (user {}): {}", id, userId, e.getMessage());
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }

    /**
     * Resynthesizes audio on-demand for older history records where audio files were not stored,
     * saving it to storage so subsequent plays are instant.
     */
    private InputStream resynthesizeAudio(com.speakit.tts.entity.TtsHistory history) {
        try {
            String text = history.getFullText() != null ? history.getFullText() : history.getTextSnippet();
            if (text == null || text.trim().isEmpty()) return null;

            String voiceId = history.getVoiceId();
            String format = history.getOutputFormat() != null ? history.getOutputFormat() : "mp3";
            InputStream stream = null;

            if ("NATURAL".equalsIgnoreCase(history.getVoiceType()) && elevenLabsService != null) {
                stream = elevenLabsService.synthesizeSpeech(text, voiceId);
            } else if ("INDIAN".equalsIgnoreCase(history.getVoiceType()) && sarvamService != null) {
                stream = sarvamService.synthesizeSpeech(text, voiceId, "hi-IN", 1.0, 22050);
            } else if (pollyService != null) {
                software.amazon.awssdk.services.polly.model.Engine engine = 
                        "NEURAL".equalsIgnoreCase(history.getVoiceType()) ? 
                        software.amazon.awssdk.services.polly.model.Engine.NEURAL : 
                        software.amazon.awssdk.services.polly.model.Engine.STANDARD;
                stream = pollyService.synthesizeSpeech(text, voiceId, format, java.util.Map.of("engine", engine));
            }

            if (stream == null) return null;
            byte[] bytes = stream.readAllBytes();

            try {
                Long ownerId = history.getUser() != null ? history.getUser().getId() : 0L;
                var stored = audioStorageService.storeAudio(ownerId, bytes, format);
                history.setAudioUrl(stored.url());
                history.setStorageKey(stored.storageKey());
                ttsHistoryRepository.save(history);
            } catch (Exception e) {
                log.warn("Failed to persist on-demand synthesized audio for history {}: {}", history.getId(), e.getMessage());
            }

            return new java.io.ByteArrayInputStream(bytes);
        } catch (Exception e) {
            log.error("On-demand synthesis failed for history ID {}: {}", history.getId(), e.getMessage());
            return null;
        }
    }

    @DeleteMapping("/delete")
    public ResponseEntity<Void> deleteSelected(
            HttpServletRequest request,
            @RequestBody @jakarta.validation.constraints.Size(max = 100, message = "Maximum 100 items can be deleted at once") List<Long> ids,
            @RequestParam(required = false, defaultValue = "ALL") String type
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String filterType = (type != null) ? type.trim().toUpperCase() : "ALL";

        if (!"STT".equals(filterType)) {
            List<com.speakit.tts.entity.TtsHistory> items = ttsHistoryRepository.findAllByIdInAndUserId(ids, userId);
            for (var item : items) {
                audioStorageService.deleteAudio(item.getStorageKey(), item.getAudioUrl());
            }
            ttsHistoryRepository.deleteAllByIdInAndUserId(ids, userId);
        }

        if (!"TTS".equals(filterType)) {
            speechToTextRequestRepository.deleteAllByIdInAndUserId(ids, userId);
        }

        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/clear-all")
    public ResponseEntity<Void> clearAll(
            HttpServletRequest request,
            @RequestParam(required = false, defaultValue = "ALL") String type
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        String filterType = (type != null) ? type.trim().toUpperCase() : "ALL";

        if (!"STT".equals(filterType)) {
            List<com.speakit.tts.entity.TtsHistory> items = ttsHistoryRepository.findAllByUserId(userId);
            for (var item : items) {
                audioStorageService.deleteAudio(item.getStorageKey(), item.getAudioUrl());
            }
            ttsHistoryRepository.deleteAllByUserId(userId);
        }

        if (!"TTS".equals(filterType)) {
            speechToTextRequestRepository.deleteAllByUserId(userId);
        }

        return ResponseEntity.noContent().build();
    }

    private MediaType getMediaType(String format) {
        if (format == null) return MediaType.parseMediaType("audio/mpeg");
        return switch (format.toLowerCase()) {
            case "mp3" -> MediaType.parseMediaType("audio/mpeg");
            case "ogg", "ogg_vorbis" -> MediaType.parseMediaType("audio/ogg");
            case "pcm", "wav", "wave" -> MediaType.parseMediaType("audio/wav");
            default -> MediaType.APPLICATION_OCTET_STREAM;
        };
    }
}
