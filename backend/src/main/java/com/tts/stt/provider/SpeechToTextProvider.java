package com.tts.stt.provider;

import com.tts.stt.dto.SpeechToTextResult;
import java.io.File;

public interface SpeechToTextProvider {
    SpeechToTextResult transcribe(File audioFile, String language);
    String getName();
}
