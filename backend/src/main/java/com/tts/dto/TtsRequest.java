package com.tts.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TtsRequest {
    @NotBlank(message = "Text cannot be blank")
    @Size(max = 1000, message = "Text cannot exceed 1000 characters")
    private String text;

    @NotNull(message = "Voice ID cannot be null")
    private String voiceId = "Joanna";   // AWS Polly voice

    @NotNull(message = "Output format cannot be null")
    private String outputFormat = "mp3";  // mp3 | ogg_vorbis | pcm
}