package com.speakit.tts.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LongFormJobStatusDto {
    private String jobId;
    private Long userId;
    private String status; // QUEUED, PROCESSING, COMPLETED, FAILED
    private int progressPercent;
    private int totalChunks;
    private int completedChunks;
    private String audioUrl;
    private String textSnippet;
    private Integer totalCharacters;
    private String voiceId;
    private String errorMessage;
    private LocalDateTime createdAt;
    private LocalDateTime completedAt;
}
