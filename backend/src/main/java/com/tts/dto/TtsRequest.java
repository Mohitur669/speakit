package com.tts.dto;

import lombok.Data;

@Data
public class TtsRequest {
    private String text;
    private String voiceId = "Joanna";   // AWS Polly voice
    private String outputFormat = "mp3";  // mp3 | ogg_vorbis | pcm
}