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
    @com.fasterxml.jackson.annotation.JsonProperty("id")
    private Long id; // Optional existing session/history ID to update if continuing an existing session

    @com.fasterxml.jackson.annotation.JsonProperty("sessionId")
    @com.fasterxml.jackson.annotation.JsonAlias({"session_id", "sessionId"})
    private String sessionId; // Client-generated unique session UUID (Idempotency key)

    @com.fasterxml.jackson.annotation.JsonProperty("sessionType")
    @com.fasterxml.jackson.annotation.JsonAlias({"session_type", "sessionType"})
    private String sessionType; // "CONVERSATION" or "SOLO"

    @com.fasterxml.jackson.annotation.JsonProperty("title")
    private String title; // "Live Conversation" or "Live Dictation"

    @com.fasterxml.jackson.annotation.JsonProperty("language")
    private String language; // "hi-IN" or "hi-IN, en-IN"

    @com.fasterxml.jackson.annotation.JsonProperty("mode")
    private String mode; // "transcribe" or "translate"

    @com.fasterxml.jackson.annotation.JsonProperty("durationSeconds")
    @com.fasterxml.jackson.annotation.JsonAlias({"duration_seconds", "durationSeconds"})
    private Integer durationSeconds;

    @NotBlank(message = "Session transcript cannot be blank")
    @com.fasterxml.jackson.annotation.JsonProperty("transcript")
    private String transcript;

    @com.fasterxml.jackson.annotation.JsonProperty("characterCount")
    @com.fasterxml.jackson.annotation.JsonAlias({"character_count", "characterCount"})
    private Integer characterCount;
}
