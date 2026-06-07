package com.tts.controller;

import com.tts.dto.TtsHistoryDto;
import com.tts.repository.TtsHistoryRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/**
 * REST controller for retrieving user-specific analytics and history.
 */
@RestController
@RequestMapping("/api/history")
@RequiredArgsConstructor
public class HistoryController {

    private final TtsHistoryRepository ttsHistoryRepository;

    @GetMapping
    public ResponseEntity<Page<TtsHistoryDto>> getHistory(
            HttpServletRequest request,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        Page<TtsHistoryDto> historyPage = ttsHistoryRepository
                .findRecentHistoryByUserId(userId, PageRequest.of(page, size))
                .map(history -> TtsHistoryDto.builder()
                        .id(history.getId())
                        .voiceId(history.getVoiceId())
                        .voiceName(history.getVoiceName())
                        .voiceType(history.getVoiceType())
                        .outputFormat(history.getOutputFormat())
                        .characterCount(history.getCharacterCount())
                        .textSnippet(history.getTextSnippet())
                        .createdAt(history.getCreatedAt())
                        .build());

        return ResponseEntity.ok(historyPage);
    }

    @DeleteMapping("/delete")
    public ResponseEntity<Void> deleteSelected(
            HttpServletRequest request,
            @RequestBody List<Long> ids
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        
        ttsHistoryRepository.deleteAllByIdInAndUserId(ids, userId);
        return ResponseEntity.noContent().build();
    }

    @DeleteMapping("/clear-all")
    public ResponseEntity<Void> clearAll(HttpServletRequest request) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        ttsHistoryRepository.deleteAllByUserId(userId);
        return ResponseEntity.noContent().build();
    }
}
