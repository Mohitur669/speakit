package com.speakit.stt.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TranslationRequest {
    @NotBlank(message = "Text cannot be blank")
    @Size(max = 10000, message = "Text is too long")
    private String text;

    @NotBlank(message = "Source language cannot be blank")
    @Pattern(regexp = "^[a-zA-Z0-9\\-\\s()]+$", message = "Invalid source language format")
    private String sourceLanguage;

    @NotBlank(message = "Target language cannot be blank")
    @Pattern(regexp = "^[a-zA-Z0-9\\-\\s()]+$", message = "Invalid target language format")
    private String targetLanguage;

    /**
     * Optional mode: "formal", "colloquial", "code-mixed"
     */
    private String mode;
}
