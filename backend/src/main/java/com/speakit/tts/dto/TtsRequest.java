package com.speakit.tts.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import jakarta.validation.constraints.Pattern;
import lombok.Data;

@Data
public class TtsRequest {
    private String text;

    /**
     * Staging token referencing a pre-validated and extracted PDF document.
     * When present, text is sourced directly from the server-side staged document cache.
     */
    private String documentToken;

    private String sourceFileName;

    private String title;

    @NotNull(message = "Voice ID cannot be null")
    @Pattern(regexp = "^[a-zA-Z0-9\\-_:]+$", message = "Invalid Voice ID format")
    private String voiceId = "Joanna";   // AWS Polly voice

    @Size(max = 100, message = "Voice name is too long")
    @Pattern(regexp = "^[\\p{L}0-9\\-_:\\s().,']+$", message = "Invalid Voice Name format")
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

    /**
     * Optional ElevenLabs v4 voice style direction tag.
     * When set, text is wrapped with <voiceStyle>text</voiceStyle> before synthesis.
     * Supported values: excited, sad, calm, angry, cheerful, terrified, unfriendly.
     * Only applied when isElevenLabs=true and the voice model supports v4 direction tags.
     */
    @Pattern(
        regexp = "^(excited|sad|calm|angry|cheerful|terrified|unfriendly)?$",
        message = "Invalid voiceStyle. Must be one of: excited, sad, calm, angry, cheerful, terrified, unfriendly"
    )
    private String voiceStyle;
}
