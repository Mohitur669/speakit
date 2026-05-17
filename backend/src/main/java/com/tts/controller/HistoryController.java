package com.tts.controller;

import com.tts.dto.TtsHistoryDto;
import com.tts.repository.TtsHistoryRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * REST controller for retrieving user-specific analytics and history.
 * 
 * Provides highly optimized, paginated endpoints to support frontend
 * dashboards without exposing raw database entities.
 */
@RestController
@RequestMapping("/api/history")
@RequiredArgsConstructor
public class HistoryController {

    private final TtsHistoryRepository ttsHistoryRepository;

    /**
     * Fetches a paginated list of TTS generation events for the authenticated user.
     * 
     * Security: Relies on the pre-cached userId attribute from the JwtAuthenticationFilter
     * to guarantee that users can only access their own history logs.
     * 
     * Performance: Maps database entities directly to DTOs to minimize the JSON
     * payload size and prevent recursive object serialization.
     * 
     * @param request The HTTP request containing the pre-authenticated userId
     * @param page The zero-based page index (defaults to 0)
     * @param size The maximum number of records per page (defaults to 20)
     * @return Paginated response containing lightweight TtsHistoryDto objects
     */
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
                        .outputFormat(history.getOutputFormat())
                        .characterCount(history.getCharacterCount())
                        .isNeural(history.isNeural())
                        .textSnippet(history.getTextSnippet())
                        .createdAt(history.getCreatedAt())
                        .build());

        return ResponseEntity.ok(historyPage);
    }
}