package com.speakit.tts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class TtsRequest {
    @NotBlank(message = "Text cannot be blank")
    @Size(max = 10000, message = "Text is too long")
    private String text;

    @NotNull(message = "Voice ID cannot be null")
    @Pattern(regexp = "^[a-zA-Z0-9\\-_:]+$", message = "Invalid Voice ID format")
    private String voiceId = "Joanna";   // AWS Polly voice

    @Size(max = 100, message = "Voice name is too long")
    @Pattern(regexp = "^[a-zA-Z0-9\\-_:\\s().,']+$", message = "Invalid Voice Name format")
    private String voiceName;            // Human readable name

    @Pattern(regexp = "^(STANDARD|NEURAL|NATURAL|INDIAN)?$", message = "Invalid Voice Type format")
    private String voiceType;            // STANDARD | NEURAL | NATURAL

    @NotNull(message = "Output format cannot be null")
    @Pattern(regexp = "^(mp3|ogg_vorbis|pcm)$", message = "Invalid output format")
    private String outputFormat = "mp3";  // mp3 | ogg_vorbis | pcm

    @JsonProperty("isElevenLabs")
    private boolean elevenLabs = false;

    @JsonProperty("isSarvam")
    private boolean sarvam = false;

    @Pattern(regexp = "^[a-zA-Z0-9\\-]+$", message = "Invalid language code")
    private String languageCode; // e.g. hi-IN, en-IN

    private Double pace = 1.0;

    private Integer samplingRate;
}
