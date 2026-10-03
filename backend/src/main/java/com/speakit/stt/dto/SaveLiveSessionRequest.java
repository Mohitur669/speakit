package com.speakit.stt.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SaveLiveSessionRequest {
    private Long id; // Optional existing session/history ID to update if continuing an existing session
    private String sessionType; // "CONVERSATION" or "SOLO"
    private String title; // "Live Conversation" or "Live Dictation"
    private String language; // "hi-IN" or "hi-IN, en-IN"
    private String mode; // "transcribe" or "translate"
    private Integer durationSeconds;

    @NotBlank(message = "Session transcript cannot be blank")
    private String transcript;

    private Integer characterCount;
}
