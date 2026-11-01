package com.speakit.tts.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DocumentAnalysisDto {
    private String documentToken;
    private String fileName;
    private long fileSizeBytes;
    private int pageCount;
    private int wordCount;
    private int characterCount;
    private int estimatedDurationSeconds;
    private String estimatedDurationFormatted;
    private String validationStatus; // "READY", "WARNING", "REJECTED"
    private List<String> warnings;
}
