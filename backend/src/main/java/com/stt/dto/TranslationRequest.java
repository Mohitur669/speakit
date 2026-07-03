package com.stt.dto;

import lombok.Data;

@Data
public class TranslationRequest {
    private String text;
    private String sourceLanguage;
    private String targetLanguage;
}
