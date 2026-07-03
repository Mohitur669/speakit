package com.speakit.tts.service;

import java.io.InputStream;
import java.util.List;
import java.util.Map;

/**
 * Common interface for Text-to-Speech engines.
 */
public interface SpeechProvider {
    InputStream synthesizeSpeech(String text, String voiceId, String format, Map<String, Object> additionalParams);
    List<Map<String, Object>> getAvailableVoices();
    boolean supports(String engineName);
}
