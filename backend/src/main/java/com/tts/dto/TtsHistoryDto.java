package com.tts.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Builder
public class TtsHistoryDto {
    private Long id;
    private String voiceId;
    private String outputFormat;
    private int characterCount;
    private boolean isNeural;
    private String textSnippet;
    private LocalDateTime createdAt;
}