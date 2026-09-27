package com.speakit.user.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.Arrays;
import java.util.List;

/**
 * Service managing user avatar upload, validation, and deletion.
 * Supports Cloudflare R2 (S3-compatible API) with public CDN distribution,
 * and graceful fallback to local disk storage when cloud credentials are unconfigured.
 */
@Service
@Slf4j
public class AvatarStorageService {

    private static final long MAX_FILE_SIZE = 2 * 1024 * 1024; // 2MB
    private static final List<String> ALLOWED_MIME_TYPES = Arrays.asList(
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/webp"
    );

    @Value("${cloudflare.r2.account-id:}")
    private String accountId;

    @Value("${cloudflare.r2.access-key-id:}")
    private String accessKeyId;

    @Value("${cloudflare.r2.secret-access-key:}")
    private String secretAccessKey;

    @Value("${cloudflare.r2.bucket-name:}")
    private String bucketName;

    @Value("${cloudflare.r2.public-url:}")
    private String publicUrl;

    private S3Client s3Client;
    private boolean r2Enabled = false;
    private final Path localFallbackDir = Paths.get("uploads", "avatars");

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
                log.info("Cloudflare R2 avatar storage client initialized successfully for bucket: {}", bucketName);
            } catch (Exception e) {
                log.error("Failed to initialize Cloudflare R2 S3 client. Falling back to local storage.", e);
                this.r2Enabled = false;
            }
        } else {
            log.info("Cloudflare R2 credentials not fully configured. Using local filesystem avatar storage.");
            this.r2Enabled = false;
        }

        try {
            Files.createDirectories(localFallbackDir);
        } catch (IOException e) {
            log.warn("Could not create local avatar fallback directory: {}", localFallbackDir, e);
        }
    }

    public record StoredAvatar(
            String url,
            String storageKey,
            long fileSizeBytes,
            String mimeType
    ) {}

    public StoredAvatar storeAvatar(Long userId, MultipartFile file) throws IOException {
        validateFile(file);

        String contentType = file.getContentType();
        String extension = getFileExtension(file);
        long timestamp = System.currentTimeMillis();
        String key = String.format("avatars/u_%d_%d%s", userId, timestamp, extension);

        if (r2Enabled && s3Client != null) {
            try {
                PutObjectRequest putRequest = PutObjectRequest.builder()
                        .bucket(bucketName.trim())
                        .key(key)
                        .contentType(contentType != null ? contentType : "image/jpeg")
                        .cacheControl("public, max-age=31536000, immutable")
                        .build();

                s3Client.putObject(putRequest, RequestBody.fromBytes(file.getBytes()));
                log.info("Successfully uploaded avatar to Cloudflare R2: {}", key);

                return new StoredAvatar(
                        buildPublicUrl(key),
                        key,
                        file.getSize(),
                        contentType != null ? contentType : "image/jpeg"
                );
            } catch (Exception e) {
                log.error("Failed to upload avatar to Cloudflare R2. Falling back to local storage.", e);
                // Fall through to local fallback below
            }
        }

        // Local storage fallback
        String fileName = String.format("u_%d_%d%s", userId, timestamp, extension);
        Path targetPath = localFallbackDir.resolve(fileName);
        Files.copy(file.getInputStream(), targetPath, StandardCopyOption.REPLACE_EXISTING);
        log.info("Avatar saved to local storage: {}", targetPath);
        return new StoredAvatar(
                "/uploads/avatars/" + fileName,
                "avatars/" + fileName,
                file.getSize(),
                contentType != null ? contentType : "image/jpeg"
        );
    }

    public void deleteAvatar(String avatarUrl) {
        deleteAvatar(null, avatarUrl);
    }

    public void deleteAvatar(String storageKey, String avatarUrl) {
        String key = storageKey;
        if ((key == null || key.isBlank()) && avatarUrl != null && !avatarUrl.isBlank()) {
            if (avatarUrl.contains("avatars/")) {
                int index = avatarUrl.indexOf("avatars/");
                key = avatarUrl.substring(index);
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
                log.info("Deleted avatar from Cloudflare R2: {}", key);
            } else if (avatarUrl != null && avatarUrl.contains("/uploads/avatars/")) {
                String fileName = avatarUrl.substring(avatarUrl.lastIndexOf('/') + 1);
                Path path = localFallbackDir.resolve(fileName);
                Files.deleteIfExists(path);
                log.info("Deleted local avatar: {}", path);
            }
        } catch (Exception e) {
            log.warn("Failed to delete avatar (key: {}, url: {}): {}", key, avatarUrl, e.getMessage());
        }
    }

    private void validateFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Avatar file must not be empty");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("Avatar file size exceeds the 2MB limit");
        }
        String contentType = file.getContentType();
        if (contentType == null || !ALLOWED_MIME_TYPES.contains(contentType.toLowerCase())) {
            throw new IllegalArgumentException("Invalid image format. Supported formats: JPEG, PNG, WebP");
        }
    }

    private String getFileExtension(MultipartFile file) {
        String contentType = file.getContentType();
        if ("image/png".equalsIgnoreCase(contentType)) return ".png";
        if ("image/webp".equalsIgnoreCase(contentType)) return ".webp";
        if ("image/jpeg".equalsIgnoreCase(contentType) || "image/jpg".equalsIgnoreCase(contentType)) return ".jpg";

        String originalName = file.getOriginalFilename();
        if (originalName != null && originalName.contains(".")) {
            return originalName.substring(originalName.lastIndexOf('.')).toLowerCase();
        }
        return ".jpg";
    }

    private String buildPublicUrl(String key) {
        if (publicUrl != null && !publicUrl.trim().isEmpty()) {
            String base = publicUrl.trim();
            if (base.endsWith("/")) {
                base = base.substring(0, base.length() - 1);
            }
            return base + "/" + key;
        }
        return String.format("https://%s.r2.cloudflarestorage.com/%s/%s", accountId.trim(), bucketName.trim(), key);
    }

    private boolean isConfigured(String val) {
        return val != null && !val.trim().isEmpty() && !val.contains("${");
    }
}
