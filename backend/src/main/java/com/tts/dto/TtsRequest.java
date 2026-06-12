package com.tts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

@Data
public class TtsRequest {
    @NotBlank(message = "Text cannot be blank")
    private String text;

    @NotNull(message = "Voice ID cannot be null")
    private String voiceId = "Joanna";   // AWS Polly voice

    private String voiceName;            // Human readable name

    private String voiceType;            // STANDARD | NEURAL | NATURAL

    @NotNull(message = "Output format cannot be null")
    private String outputFormat = "mp3";  // mp3 | ogg_vorbis | pcm

    @JsonProperty("isElevenLabs")
    private boolean elevenLabs = false;

    @JsonProperty("isSarvam")
    private boolean sarvam = false;

    private String languageCode; // e.g. hi-IN, en-IN

    private Double pace = 1.0;

    private Integer samplingRate;
}
