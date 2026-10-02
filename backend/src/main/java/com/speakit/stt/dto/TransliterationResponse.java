package com.speakit.stt.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class TransliterationResponse {

    private String transliteratedText;
    private String sourceLanguage;
    private String targetLanguage;
}
