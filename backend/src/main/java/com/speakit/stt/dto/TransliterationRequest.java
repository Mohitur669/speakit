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
public class TransliterationRequest {

    @NotBlank(message = "Text cannot be blank")
    private String text;

    /**
     * Source language code (e.g. "hi-IN", "ta-IN", "en-IN").
     */
    private String sourceLanguage;

    /**
     * Target language code or script format (e.g. "en-IN", "hi-IN", "Latin", "Devanagari").
     */
    private String targetLanguage;
}
