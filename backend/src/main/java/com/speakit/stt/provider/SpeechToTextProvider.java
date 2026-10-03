package com.speakit.stt.provider;

import com.speakit.stt.dto.SpeechToTextResult;
import java.io.File;

public interface SpeechToTextProvider {
    SpeechToTextResult transcribe(File audioFile, String language);

    default SpeechToTextResult transcribe(File audioFile, String language, String mode) {
        return transcribe(audioFile, language);
    }

    String getName();
}
