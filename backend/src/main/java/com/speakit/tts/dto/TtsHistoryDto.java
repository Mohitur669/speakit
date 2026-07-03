package com.speakit.tts.dto;

import lombok.Builder;
import lombok.Data;
import java.time.LocalDateTime;

@Data
@Builder
public class TtsHistoryDto {
    private Long id;
    private String voiceId;
    private String voiceName;
    private String voiceType; // STANDARD, NEURAL, NATURAL
    private String outputFormat;
    private int characterCount;
    private String textSnippet;
    private LocalDateTime createdAt;
}
