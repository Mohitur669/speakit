package com.stt.provider;

import com.stt.dto.SpeechToTextResult;
import java.io.File;

public interface SpeechToTextProvider {
    SpeechToTextResult transcribe(File audioFile, String language);
    String getName();
}
