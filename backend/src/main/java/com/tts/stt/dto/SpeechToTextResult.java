package com.tts.stt.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SpeechToTextResult {
    private String transcript;
    private String language;
    private Double duration;
    private String provider;
}
