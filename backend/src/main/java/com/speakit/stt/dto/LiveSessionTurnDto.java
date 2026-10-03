package com.speakit.stt.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LiveSessionTurnDto {

    @JsonProperty("turnIndex")
    @JsonAlias({"turn_index", "turnIndex"})
    private Integer turnIndex;

    @JsonProperty("speakerRole")
    @JsonAlias({"speaker_role", "speakerRole"})
    private String speakerRole; // "PERSON_A", "PERSON_B", "SOLO"

    @JsonProperty("speakerName")
    @JsonAlias({"speaker_name", "speakerName"})
    private String speakerName;

    @JsonProperty("sourceLanguage")
    @JsonAlias({"source_language", "sourceLanguage"})
    private String sourceLanguage;

    @JsonProperty("originalText")
    @JsonAlias({"original_text", "originalText"})
    private String originalText;

    @JsonProperty("targetLanguage")
    @JsonAlias({"target_language", "targetLanguage"})
    private String targetLanguage;

    @JsonProperty("translatedText")
    @JsonAlias({"translated_text", "translatedText"})
    private String translatedText;

    @JsonProperty("characterCount")
    @JsonAlias({"character_count", "characterCount"})
    private Integer characterCount;
}
