package com.speakit.tts.validator;

import com.speakit.billing.entity.PlanType;
import com.speakit.billing.service.SubscriptionService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;

@Component
@RequiredArgsConstructor
@Slf4j
public class PdfDocumentValidator {

    private final SubscriptionService subscriptionService;
    private static final byte[] PDF_MAGIC_BYTES = new byte[]{0x25, 0x50, 0x44, 0x46, 0x2D}; // %PDF-

    /**
     * Validates PDF file extension, MIME type, filename security, file size limits, and binary signature.
     */
    public void validate(MultipartFile file, PlanType planType) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("PDF document is required.");
        }

        String filename = file.getOriginalFilename();
        if (filename == null || filename.isBlank()) {
            throw new IllegalArgumentException("Invalid filename.");
        }

        if (filename.contains("..") || filename.contains("/") || filename.contains("\\")) {
            throw new IllegalArgumentException("Path traversal or invalid characters detected in filename.");
        }

        // 1. Single extension check
        if (filename.split("\\.").length > 2) {
            throw new IllegalArgumentException("Double extensions are forbidden for security reasons.");
        }

        // 2. Extension check
        int dotIndex = filename.lastIndexOf('.');
        String ext = (dotIndex != -1) ? filename.substring(dotIndex + 1).toLowerCase() : "";
        if (!"pdf".equals(ext)) {
            throw new IllegalArgumentException("Only PDF documents (.pdf) are supported.");
        }

        // 3. MIME type check
        String contentType = file.getContentType();
        if (contentType != null) {
            int semi = contentType.indexOf(';');
            if (semi != -1) {
                contentType = contentType.substring(0, semi).trim();
            }
            if (!"application/pdf".equalsIgnoreCase(contentType) && !"application/x-pdf".equalsIgnoreCase(contentType)) {
                log.warn("MIME spoofing detected for {}: contentType={}", filename, file.getContentType());
                throw new IllegalArgumentException("Invalid PDF format detected.");
            }
        }

        // 4. File size check per plan
        long maxBytes = subscriptionService.getPdfMaxFileSizeBytes(planType);
        if (file.getSize() > maxBytes) {
            long maxMb = maxBytes / (1024 * 1024);
            throw new IllegalArgumentException(String.format("The uploaded file exceeds the maximum permitted file size of %d MB for your %s plan.", maxMb, planType != null ? planType.name() : "FREE"));
        }

        // 5. Binary magic byte signature check (%PDF-)
        try (InputStream is = file.getInputStream()) {
            byte[] header = new byte[5];
            int read = is.read(header);
            if (read < 5 || !Arrays.equals(header, PDF_MAGIC_BYTES)) {
                throw new IllegalArgumentException("Invalid PDF signature. The uploaded file is not a valid PDF document.");
            }
        } catch (IOException e) {
            log.error("Failed to read PDF file header: {}", filename, e);
            throw new IllegalArgumentException("Could not read uploaded PDF document.");
        }
    }
}
