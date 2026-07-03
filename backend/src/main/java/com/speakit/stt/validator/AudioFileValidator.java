package com.speakit.stt.validator;

import com.speakit.stt.exception.SttException;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.util.Arrays;
import java.util.List;

@Component
@Slf4j
public class AudioFileValidator {

    private static final List<String> ALLOWED_EXTENSIONS = Arrays.asList("mp3", "wav", "m4a", "ogg", "webm");
    private static final List<String> ALLOWED_MIME_TYPES = Arrays.asList(
        "audio/mpeg", "audio/wav", "audio/x-wav", "audio/mp4", "audio/ogg", "application/ogg", "audio/webm", "video/webm"
    );

    public void validate(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new SttException("Audio file is required.");
        }

        String filename = file.getOriginalFilename();
        if (filename == null || filename.contains("..")) {
            throw new SttException("Invalid filename detected.");
        }

        // 1. Extension Check
        String extension = getFileExtension(filename);
        if (!ALLOWED_EXTENSIONS.contains(extension.toLowerCase())) {
            throw new SttException("Unsupported file extension: " + extension);
        }

        // 2. MIME Type Check
        String contentType = file.getContentType();
        if (contentType != null) {
            int semicolonIndex = contentType.indexOf(";");
            if (semicolonIndex != -1) {
                contentType = contentType.substring(0, semicolonIndex).trim();
            }
        }
        if (contentType == null || !ALLOWED_MIME_TYPES.contains(contentType.toLowerCase())) {
            log.warn("Potential MIME spoofing detected: {} for file {}", file.getContentType(), filename);
            throw new SttException("Invalid audio format detected.");
        }

        // 3. Double Extension / Malware Prevention
        if (filename.split("\\.").length > 2) {
            throw new SttException("Double extensions are forbidden for security reasons.");
        }
    }

    private String getFileExtension(String filename) {
        int lastDotIndex = filename.lastIndexOf(".");
        if (lastDotIndex == -1) return "";
        return filename.substring(lastDotIndex + 1);
    }
}
