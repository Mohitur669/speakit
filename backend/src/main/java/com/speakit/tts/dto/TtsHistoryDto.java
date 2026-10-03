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
public class TtsHistoryDto {
    private Long id;
    private String sessionId;
    private String voiceId;
    private String voiceName;
    private String voiceType; // STANDARD, NEURAL, NATURAL, INDIAN, or STT
    private String outputFormat;
    private int characterCount;
    private String textSnippet;
    private String fullText;
    private String audioUrl;
    private LocalDateTime createdAt;

    // Unified Activity & STT extensions
    @Builder.Default
    private String engineType = "TTS"; // "TTS" or "STT"
    private String transliteration;
    private String mode; // e.g. "transcribe", "translate", "transliterate"
    private String filename; // original file name if uploaded
    private String status; // SUCCESS, FAILED, etc.
}
