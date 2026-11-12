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
     * Defaults to translate-audio/ folder prefix for Text-to-Speech synthesis.
     */
    public StoredAudio storeAudio(Long userId, byte[] audioBytes, String format) throws IOException {
        return storeTranslateAudio(userId, audioBytes, format);
    }

    /**
     * Stores Text-to-Speech / Translate audio under translate-audio/ prefix.
     */
    public StoredAudio storeTranslateAudio(Long userId, byte[] audioBytes, String format) throws IOException {
        return storeAudio(userId, audioBytes, format, "translate-audio");
    }

    /**
     * Stores Speech-to-Text / Transcribe audio under transcribe-audio/ prefix.
     */
    public StoredAudio storeTranscribeAudio(Long userId, byte[] audioBytes, String format) throws IOException {
        return storeAudio(userId, audioBytes, format, "transcribe-audio");
    }

    /**
     * Stores long-form document/PDF audiobook audio in Cloudflare R2 under pdf-audio/ prefix.
     */
    public StoredAudio storePdfAudio(Long userId, byte[] audioBytes, String format) throws IOException {
        return storeAudio(userId, audioBytes, format, "pdf-audio");
    }

    /**
     * Stores synthesized audio in Cloudflare R2 or local disk under a specified folder prefix.
     */
    public StoredAudio storeAudio(Long userId, byte[] audioBytes, String format, String folderPrefix) throws IOException {
        if (audioBytes == null || audioBytes.length == 0) {
            throw new IllegalArgumentException("Audio bytes must not be empty");
        }

        String prefix = (folderPrefix != null && !folderPrefix.isBlank()) ? folderPrefix.trim() : "translate-audio";
        if (prefix.endsWith("/")) {
            prefix = prefix.substring(0, prefix.length() - 1);
        }

        String extension = getExtension(format);
        String mimeType = getMimeType(format);
        long timestamp = System.currentTimeMillis();
        String uniqueSuffix = UUID.randomUUID().toString().substring(0, 8);
        String key = String.format("%s/u_%d_%d_%s%s", prefix, userId != null ? userId : 0, timestamp, uniqueSuffix, extension);

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
        Path targetDir = Paths.get("uploads", prefix);
        Files.createDirectories(targetDir);

        String fileName = String.format("u_%d_%d_%s%s", userId != null ? userId : 0, timestamp, uniqueSuffix, extension);
        Path targetPath = targetDir.resolve(fileName).normalize().toAbsolutePath();
        if (!targetPath.startsWith(targetDir.toAbsolutePath().normalize())) {
            throw new SecurityException("Path traversal attempt detected in audio filename: " + fileName);
        }
        Files.write(targetPath, audioBytes, StandardOpenOption.CREATE, StandardOpenOption.TRUNCATE_EXISTING);
        log.info("Synthesized audio saved to local storage: {}", targetPath);

        return new StoredAudio(
                "/uploads/" + prefix + "/" + fileName,
                prefix + "/" + fileName,
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
            for (String p : new String[]{"translate-audio/", "transcribe-audio/", "pdf-audio/", "audio/"}) {
                if (audioUrl.contains(p)) {
                    key = audioUrl.substring(audioUrl.indexOf(p));
                    if (key.contains("?")) {
                        key = key.substring(0, key.indexOf("?"));
                    }
                    break;
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
        if (key != null && (key.startsWith("translate-audio/") || key.startsWith("transcribe-audio/") || key.startsWith("pdf-audio/") || key.startsWith("audio/"))) {
            String prefixPart = key.substring(0, key.indexOf('/'));
            Path dir = Paths.get("uploads", prefixPart);
            String rawFileName = key.substring(key.lastIndexOf('/') + 1);
            if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                Path path = dir.resolve(rawFileName).normalize().toAbsolutePath();
                if (path.startsWith(dir.toAbsolutePath().normalize()) && Files.exists(path)) {
                    return Files.newInputStream(path);
                }
            }
        } else if (audioUrl != null && audioUrl.contains("/uploads/")) {
            for (String p : new String[]{"/uploads/translate-audio/", "/uploads/transcribe-audio/", "/uploads/pdf-audio/", "/uploads/audio/"}) {
                if (audioUrl.contains(p)) {
                    String prefixPart = p.replace("/uploads/", "").replace("/", "");
                    Path dir = Paths.get("uploads", prefixPart);
                    String rawFileName = audioUrl.substring(audioUrl.lastIndexOf('/') + 1);
                    if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                        Path path = dir.resolve(rawFileName).normalize().toAbsolutePath();
                        if (path.startsWith(dir.toAbsolutePath().normalize()) && Files.exists(path)) {
                            return Files.newInputStream(path);
                        }
                    }
                    break;
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
            for (String p : new String[]{"translate-audio/", "transcribe-audio/", "pdf-audio/", "audio/"}) {
                if (audioUrl.contains(p)) {
                    key = audioUrl.substring(audioUrl.indexOf(p));
                    if (key.contains("?")) {
                        key = key.substring(0, key.indexOf("?"));
                    }
                    break;
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
            } else if (key != null && (key.startsWith("translate-audio/") || key.startsWith("transcribe-audio/") || key.startsWith("pdf-audio/") || key.startsWith("audio/"))) {
                String prefixPart = key.substring(0, key.indexOf('/'));
                Path dir = Paths.get("uploads", prefixPart);
                String rawFileName = key.substring(key.lastIndexOf('/') + 1);
                if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                    Path path = dir.resolve(rawFileName).normalize().toAbsolutePath();
                    if (path.startsWith(dir.toAbsolutePath().normalize())) {
                        Files.deleteIfExists(path);
                        log.info("Deleted local audio: {}", path);
                    }
                }
            } else if (audioUrl != null && audioUrl.contains("/uploads/")) {
                for (String p : new String[]{"/uploads/translate-audio/", "/uploads/transcribe-audio/", "/uploads/pdf-audio/", "/uploads/audio/"}) {
                    if (audioUrl.contains(p)) {
                        String prefixPart = p.replace("/uploads/", "").replace("/", "");
                        Path dir = Paths.get("uploads", prefixPart);
                        String rawFileName = audioUrl.substring(audioUrl.lastIndexOf('/') + 1);
                        if (rawFileName.matches("^[a-zA-Z0-9_.-]+$")) {
                            Path path = dir.resolve(rawFileName).normalize().toAbsolutePath();
                            if (path.startsWith(dir.toAbsolutePath().normalize())) {
                                Files.deleteIfExists(path);
                                log.info("Deleted local audio: {}", path);
                            }
                        }
                        break;
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
