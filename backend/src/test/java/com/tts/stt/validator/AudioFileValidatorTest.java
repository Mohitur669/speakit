package com.tts.stt.validator;

import com.tts.stt.exception.SttException;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;

class AudioFileValidatorTest {

    private final AudioFileValidator validator = new AudioFileValidator();

    @Test
    void validate_ValidFile_Success() {
        MockMultipartFile file = new MockMultipartFile(
            "file", "audio.mp3", "audio/mpeg", new byte[10]
        );
        assertDoesNotThrow(() -> validator.validate(file));
    }

    @Test
    void validate_ValidWebMFile_Success() {
        MockMultipartFile file1 = new MockMultipartFile(
            "file", "audio.webm", "audio/webm", new byte[10]
        );
        MockMultipartFile file2 = new MockMultipartFile(
            "file", "audio.webm", "video/webm", new byte[10]
        );
        MockMultipartFile file3 = new MockMultipartFile(
            "file", "audio.webm", "audio/webm;codecs=opus", new byte[10]
        );
        MockMultipartFile file4 = new MockMultipartFile(
            "file", "audio.webm", "video/webm;codecs=vp9,opus", new byte[10]
        );
        assertDoesNotThrow(() -> validator.validate(file1));
        assertDoesNotThrow(() -> validator.validate(file2));
        assertDoesNotThrow(() -> validator.validate(file3));
        assertDoesNotThrow(() -> validator.validate(file4));
    }

    @Test
    void validate_InvalidExtension_ThrowsException() {
        MockMultipartFile file = new MockMultipartFile(
            "file", "script.exe", "audio/mpeg", new byte[10]
        );
        assertThrows(SttException.class, () -> validator.validate(file));
    }

    @Test
    void validate_MimeMismatch_ThrowsException() {
        MockMultipartFile file = new MockMultipartFile(
            "file", "audio.mp3", "application/javascript", new byte[10]
        );
        assertThrows(SttException.class, () -> validator.validate(file));
    }

    @Test
    void validate_DoubleExtension_ThrowsException() {
        MockMultipartFile file = new MockMultipartFile(
            "file", "audio.mp3.exe", "audio/mpeg", new byte[10]
        );
        assertThrows(SttException.class, () -> validator.validate(file));
    }

    @Test
    void validate_PathTraversal_ThrowsException() {
        MockMultipartFile file = new MockMultipartFile(
            "file", "../etc/passwd", "audio/mpeg", new byte[10]
        );
        assertThrows(SttException.class, () -> validator.validate(file));
    }
}
