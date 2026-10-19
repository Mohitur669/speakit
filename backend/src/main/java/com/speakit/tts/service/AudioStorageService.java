package com.speakit.tts.service;

import lombok.extern.slf4j.Slf4j;
import org.jspecify.annotations.Nullable;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardOpenOption;
import java.util.UUID;

/**
 * Service managing synthesized audio file storage, streaming, and deletion.
 * Supports Cloudflare R2 (S3-compatible API) with zero egress fees and public CDN distribution,
 * with graceful fallback to local disk storage when cloud credentials are unconfigured.
 */
@Service
@Slf4j
public class AudioStorageService {

    @Value("${cloudflare.r2.account-id:}")
    private String accountId;

    @Value("${cloudflare.r2.access-key-id:}")
    private String accessKeyId;

    @Value("${cloudflare.r2.secret-access-key:}")
    private String secretAccessKey;

    @Value("${cloudflare.r2.audio-bucket-name:${cloudflare.r2.bucket-name:}}")
    private String bucketName;

    @Value("${cloudflare.r2.audio-public-url:${cloudflare.r2.public-url:}}")
    private String publicUrl;

    private S3Client s3Client;
    private boolean r2Enabled = false;
    private final Path localFallbackDir = Paths.get("uploads", "audio");

    @PostConstruct
    public void init() {
        if (isConfigured(accountId) && isConfigured(accessKeyId) && 
            isConfigured(secretAccessKey) && isConfigured(bucketName)) {
            try {
                String endpoint = String.format("https://%s.r2.cloudflarestorage.com", accountId.trim());
                this.s3Client = S3Client.builder()
                        .endpointOverride(URI.create(endpoint))
                        .credentialsProvider(StaticCredentialsProvider.create(
                                AwsBasicCredentials.create(accessKeyId.trim(), secretAccessKey.trim())
                        ))
                        .region(Region.of("auto"))
                        .serviceConfiguration(S3Configuration.builder()
                                .pathStyleAccessEnabled(true)
                                .build())
                        .build();
                this.r2Enabled = true;
                log.info("Cloudflare R2 audio storage client initialized successfully for bucket: {}", bucketName);
            } catch (Exception e) {
                log.error("Failed to initialize Cloudflare R2 audio S3 client. Falling back to local storage.", e);
                this.r2Enabled = false;
            }
        } else {
            log.info("Cloudflare R2 credentials not fully configured for audio. Using local filesystem audio storage.");
            this.r2Enabled = false;
        }

        try {
            Files.createDirectories(localFallbackDir);
        } catch (IOException e) {
            log.warn("Could not create local audio fallback directory: {}", localFallbackDir, e);
        }
    }

    public record StoredAudio(
            String url,
            String storageKey,
            long fileSizeBytes,
            String mimeType
    ) {}

    /**
     * Stores synthesized audio bytes in Cloudflare R2 or local disk fallback.
     */
    public StoredAudio storeAudio(Long userId, byte[] audioBytes, String format) throws IOException {
        if (audioBytes == null || audioBytes.length == 0) {
            throw new IllegalArgumentException("Audio bytes must not be empty");
        }

        String extension = getExtension(format);
        String mimeType = getMimeType(format);
        long timestamp = System.currentTimeMillis();
        String uniqueSuffix = UUID.randomUUID().toString().substring(0, 8);
        String key = String.format("audio/u_%d_%d_%s%s", userId != null ? userId : 0, timestamp, uniqueSuffix, extension);

        if (r2Enabled && s3Client != null) {
            try {
                PutObjectRequest putRequest = PutObjectRequest.builder()
                        .bucket(bucketName.trim())
                        .key(key)
                        .contentType(mimeType)
                        .cacheControl("public, max-age=31536000, immutable")
                        .build();

                s3Client.putObject(putRequest, RequestBody.fromBytes(audioBytes));
                log.info("Successfully uploaded audio to Cloudflare R2: {} ({} bytes)", key, audioBytes.length);

                return new StoredAudio(
                        buildPublicUrl(key),
                        key,
                        audioBytes.length,
                        mimeType
                );
            } catch (Exception e) {
                log.error("Failed to upload audio to Cloudflare R2. Falling back to local storage.", e);
                // Fall through to local fallback below
            }
        }

        // Local filesystem fallback
        String fileName = String.format("u_%d_%d_%s%s", userId != null ? userId : 0, timestamp, uniqueSuffix, extension);
        Path targetPath = localFallbackDir.resolve(fileName).normalize().toAbsolutePath();
        if (!targetPath.startsWith(localFallbackDir.toAbsolutePath().normalize())) {
            throw new SecurityException("Path traversal attempt detected in audio filename: " + fileName);
        }
        Files.write(targetPath, audioBytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        log.info("Synthesized audio saved to local storage: {}", targetPath);

        return new StoredAudio(
                "/uploads/audio/" + fileName,
                "audio/" + fileName,
                audioBytes.length,
                mimeType
        );
    }

    /**
     * Retrieves an input stream for audio stored in R2 or local disk fallback.
     */
    public @Nullable InputStream getAudioInputStream(String storageKey, String audioUrl) throws IOException {
        String key = storageKey;
        if ((key == null || key.isBlank()) && audioUrl != null && !audioUrl.isBlank()) {
            if (audioUrl.contains("audio/")) {
                int index = audioUrl.indexOf("audio/");
                key = audioUrl.substring(index);
                if (key.contains("?")) {
                    key = key.substring(0, key.indexOf("?"));
                }
            }
        }

        if (r2Enabled && s3Client != null && key != null && !key.isBlank()) {
            try {
                return s3Client.getObject(GetObjectRequest.builder()
                        .bucket(bucketName.trim())
                        .key(key)
                        .build());
            } catch (Exception e) {
                log.warn("Could not retrieve audio from Cloudflare R2 for key {}: {}", key, e.getMessage());
            }
        }

        // Check local storage fallback
        if (audioUrl != null && audioUrl.contains("/uploads/audio/")) {
            String rawFileName = audioUrl.substring(audioUrl.lastIndexOf('/') + 1);
            if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                Path path = localFallbackDir.resolve(rawFileName).normalize().toAbsolutePath();
                if (path.startsWith(localFallbackDir.toAbsolutePath().normalize()) && Files.exists(path)) {
                    return Files.newInputStream(path);
                }
            }
        } else if (key != null && key.startsWith("audio/")) {
            String rawFileName = key.substring(key.lastIndexOf('/') + 1);
            if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                Path path = localFallbackDir.resolve(rawFileName).normalize().toAbsolutePath();
                if (path.startsWith(localFallbackDir.toAbsolutePath().normalize()) && Files.exists(path)) {
                    return Files.newInputStream(path);
                }
            }
        }

        return null;
    }

    /**
     * Deletes audio from Cloudflare R2 or local filesystem.
     */
    public void deleteAudio(String storageKey, String audioUrl) {
        String key = storageKey;
        if ((key == null || key.isBlank()) && audioUrl != null && !audioUrl.isBlank()) {
            if (audioUrl.contains("audio/")) {
                int index = audioUrl.indexOf("audio/");
                key = audioUrl.substring(index);
                if (key.contains("?")) {
                    key = key.substring(0, key.indexOf("?"));
                }
            }
        }

        try {
            if (r2Enabled && s3Client != null && key != null && !key.isBlank()) {
                s3Client.deleteObject(DeleteObjectRequest.builder()
                        .bucket(bucketName.trim())
                        .key(key)
                        .build());
                log.info("Deleted audio from Cloudflare R2: {}", key);
            } else if (audioUrl != null && audioUrl.contains("/uploads/audio/")) {
                String rawFileName = audioUrl.substring(audioUrl.lastIndexOf('/') + 1);
                if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                    Path path = localFallbackDir.resolve(rawFileName).normalize().toAbsolutePath();
                    if (path.startsWith(localFallbackDir.toAbsolutePath().normalize())) {
                        Files.deleteIfExists(path);
                        log.info("Deleted local audio: {}", path);
                    }
                }
            }
        } catch (Exception e) {
            log.warn("Failed to delete audio (key: {}, url: {}): {}", key, audioUrl, e.getMessage());
        }
    }

    public String buildPublicUrl(String key) {
        if (publicUrl != null && !publicUrl.trim().isEmpty()) {
            String base = publicUrl.trim();
            if (base.endsWith("/")) {
                base = base.substring(0, base.length() - 1);
            }
            return base + "/" + key;
        }
        return String.format("https://%s.r2.cloudflarestorage.com/%s/%s", accountId.trim(), bucketName.trim(), key);
    }

    private String getExtension(String format) {
        if (format == null) return ".mp3";
        return switch (format.toLowerCase().trim()) {
            case "ogg", "ogg_vorbis" -> ".ogg";
            case "pcm", "wav", "wave" -> ".wav";
            default -> ".mp3";
        };
    }

    private String getMimeType(String format) {
        if (format == null) return "audio/mpeg";
        return switch (format.toLowerCase().trim()) {
            case "ogg", "ogg_vorbis" -> "audio/ogg";
            case "pcm", "wav", "wave" -> "audio/wav";
            default -> "audio/mpeg";
        };
    }

    private boolean isConfigured(String val) {
        return val != null && !val.trim().isEmpty() && !val.contains("${");
    }
}
