package com.speakit.notification.service;

import com.speakit.notification.dto.LogBackupResult;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.S3Configuration;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.net.URI;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.ZonedDateTime;
import java.time.format.DateTimeFormatter;
import java.util.zip.GZIPOutputStream;

/**
 * Cloudflare R2 Log Backup Service.
 *
 * Implements:
 * - Automated nightly backup via @Scheduled at 12:00 AM (00:00:00).
 * - On-demand manual disaster backup triggerable by authenticated users.
 * - Streams and compresses active log file as gzip (.log.gz) via in-memory buffer without file locking.
 * - Standardized R2 key format: speakit-backend/speakit-backend-{trigger}-{TIMESTAMP}.log.gz.
 * - Dynamic directory resolution (Coolify host mount path or local fallback 'logs/speakit-backend.log').
 */
@Service
@Slf4j
public class LogBackupService {

    @Value("${cloudflare.r2.logs.account-id:${cloudflare.r2.account-id:}}")
    private String accountId;

    @Value("${cloudflare.r2.logs.bucket-name:}")
    private String bucketName;

    @Value("${cloudflare.r2.logs.access-key-id:}")
    private String accessKeyId;

    @Value("${cloudflare.r2.logs.secret-access-key:}")
    private String secretAccessKey;

    @Value("${cloudflare.r2.logs.coolify-dir:}")
    private String coolifyLogsDir;

    @Value("${cloudflare.r2.logs.local-dir:logs/speakit-backend.log}")
    private String localLogsDir;

    @Value("${cloudflare.r2.logs.environment:local}")
    private String logEnvironment;

    private S3Client s3Client;
    private boolean r2Enabled = false;

    private static final DateTimeFormatter YEAR_FORMATTER = DateTimeFormatter.ofPattern("yyyy");
    private static final DateTimeFormatter TIMESTAMP_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd_HH-mm-ss");

    @PostConstruct
    public void init() {
        if (isConfigured(accountId) && isConfigured(bucketName) &&
            isConfigured(accessKeyId) && isConfigured(secretAccessKey)) {
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
                log.info("Cloudflare R2 Log Backup client initialized successfully for bucket: {}", bucketName.trim());
            } catch (Exception e) {
                log.error("Failed to initialize Cloudflare R2 Log Backup client.", e);
                this.r2Enabled = false;
            }
        } else {
            log.info("Cloudflare R2 Log Backup credentials not fully configured. Automatic and manual backups disabled.");
            this.r2Enabled = false;
        }
    }

    /**
     * Nightly scheduled backup running at 12:00 AM (midnight) server time.
     */
    @Scheduled(cron = "0 0 0 * * *")
    public void scheduledMidnightBackup() {
        log.info("Starting scheduled midnight log backup to Cloudflare R2...");
        try {
            LogBackupResult result = backupActiveLog("scheduled");
            log.info("Midnight log backup finished with status: {} (key: {})", result.getStatus(), result.getObjectKey());
        } catch (Exception e) {
            log.error("Error during scheduled midnight log backup: {}", e.getMessage(), e);
        }
    }

    /**
     * Executes backup for active speakit-backend.log, compresses with gzip, and uploads to R2.
     *
     * @param trigger "scheduled" or "manual"
     * @return LogBackupResult telemetry payload
     */
    public LogBackupResult backupActiveLog(String trigger) {
        return backupActiveLog(trigger, "scheduled".equalsIgnoreCase(trigger) ? "system" : "unknown");
    }

    /**
     * Executes backup for active speakit-backend.log with explicit actor tracking.
     *
     * @param trigger     "scheduled" or "manual"
     * @param triggeredBy Actor description (e.g. "system" or "mohitur (id: 1)")
     * @return LogBackupResult telemetry payload
     */
    public LogBackupResult backupActiveLog(String trigger, String triggeredBy) {
        long startTime = System.currentTimeMillis();
        Instant nowUtc = Instant.now();
        ZonedDateTime zdt = nowUtc.atZone(ZoneOffset.UTC);

        String safeBucket = (bucketName != null) ? bucketName.trim() : "";

        if (!r2Enabled || s3Client == null) {
            return LogBackupResult.builder()
                    .status("SKIPPED")
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .message("R2 Log Backup is disabled because credentials or bucket name are unconfigured.")
                    .timestamp(nowUtc)
                    .durationMs(System.currentTimeMillis() - startTime)
                    .build();
        }

        File logFile = resolveActiveLogFile();
        if (logFile == null || !logFile.exists() || !logFile.isFile()) {
            log.warn("Active log file not found. Checked locations: coolifyDir='{}', default='logs/speakit-backend.log'", coolifyLogsDir);
            return LogBackupResult.builder()
                    .status("SKIPPED")
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .message("No active log file found on disk.")
                    .timestamp(nowUtc)
                    .durationMs(System.currentTimeMillis() - startTime)
                    .build();
        }

        long originalSizeBytes = logFile.length();
        if (originalSizeBytes == 0) {
            return LogBackupResult.builder()
                    .status("SKIPPED")
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .message("Active log file is currently empty (0 bytes).")
                    .timestamp(nowUtc)
                    .durationMs(System.currentTimeMillis() - startTime)
                    .build();
        }

        String year = zdt.format(YEAR_FORMATTER);
        String timestamp = zdt.format(TIMESTAMP_FORMATTER);
        // Destination format: <bucket_name>/speakit-backend/<YYYY>/speakit-backend-<trigger>-<TIMESTAMP>.log.gz
        String activeObjectKey = String.format("speakit-backend/%s/speakit-backend-%s-%s.log.gz", year, trigger, timestamp);

        try {
            // 1. In-memory streaming gzip compression of active log
            byte[] compressedBytes = compressGzip(logFile);
            long compressedSizeBytes = compressedBytes.length;

            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(safeBucket)
                    .key(activeObjectKey)
                    .contentType("application/gzip")
                    .build();

            PutObjectResponse response = s3Client.putObject(putRequest, RequestBody.fromBytes(compressedBytes));

            double ratio = (1.0 - ((double) compressedSizeBytes / (double) originalSizeBytes)) * 100.0;
            String compressionRatioStr = String.format("%.2f%%", Math.max(0.0, ratio));

            // 2. Sync any historical/exceeded chunks (*.gz) to <bucket_name>/speakit-backend/<YYYY>/archive/<chunk_name>.gz
            java.util.List<String> archivedKeys = uploadRolledArchives(logFile.getParentFile(), safeBucket, year);

            long duration = System.currentTimeMillis() - startTime;
            int totalFiles = 1 + archivedKeys.size();
            log.info("Successfully uploaded active log snapshot and {} rolled chunks to Cloudflare R2: {} ({} -> {} bytes, -{}, {}ms, triggeredBy: {})",
                    archivedKeys.size(), activeObjectKey, originalSizeBytes, compressedSizeBytes, compressionRatioStr, duration, triggeredBy);

            return LogBackupResult.builder()
                    .status("SUCCESS")
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .objectKey(activeObjectKey)
                    .archivedChunksUploaded(archivedKeys)
                    .totalFilesUploaded(totalFiles)
                    .originalSizeBytes(originalSizeBytes)
                    .compressedSizeBytes(compressedSizeBytes)
                    .compressionRatio(compressionRatioStr)
                    .durationMs(duration)
                    .eTag(response.eTag())
                    .message(String.format("Log snapshot and %d exceeded archive chunk(s) successfully backed up to Cloudflare R2.", archivedKeys.size()))
                    .timestamp(nowUtc)
                    .build();

        } catch (Exception e) {
            long duration = System.currentTimeMillis() - startTime;
            log.error("Failed to backup log to Cloudflare R2: {}", e.getMessage(), e);
            return LogBackupResult.builder()
                    .status("FAILED")
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .objectKey(activeObjectKey)
                    .originalSizeBytes(originalSizeBytes)
                    .message("Backup failed: " + e.getMessage())
                    .durationMs(duration)
                    .timestamp(nowUtc)
                    .build();
        }
    }

    /**
     * Resolves the active log file based on LOG_ENVIRONMENT ("local" vs "coolify").
     * - If LOG_ENVIRONMENT is "local" (default): Resolves via LOCAL_LOGS_DIR (e.g. logs/speakit-backend.log or backend/logs/speakit-backend.log).
     * - If LOG_ENVIRONMENT is "coolify": Resolves via COOLIFY_LOGS_DIR.
     */
    private File resolveActiveLogFile() {
        String env = cleanEnv(logEnvironment);

        if ("coolify".equalsIgnoreCase(env)) {
            if (isConfigured(coolifyLogsDir)) {
                Path coolifyPath = Paths.get(coolifyLogsDir.trim());
                if (Files.isRegularFile(coolifyPath)) {
                    return coolifyPath.toFile();
                }
                Path candidateInCoolify = coolifyPath.resolve("speakit-backend.log");
                if (Files.exists(candidateInCoolify) && Files.isRegularFile(candidateInCoolify)) {
                    return candidateInCoolify.toFile();
                }
            }
            log.warn("Log environment configured as 'coolify' but no valid log file found at coolifyLogsDir='{}'", coolifyLogsDir);
            return null;
        }

        // Local environment resolution
        if (isConfigured(localLogsDir)) {
            Path customLocal = Paths.get(localLogsDir.trim());
            if (Files.isRegularFile(customLocal)) {
                return customLocal.toFile();
            }
            Path candidateInCustom = customLocal.resolve("speakit-backend.log");
            if (Files.exists(candidateInCustom) && Files.isRegularFile(candidateInCustom)) {
                return candidateInCustom.toFile();
            }
        }

        // Standard local fallbacks
        Path localDefault = Paths.get("logs", "speakit-backend.log");
        if (Files.exists(localDefault) && Files.isRegularFile(localDefault)) {
            return localDefault.toFile();
        }

        Path relativeToCurrent = Paths.get("backend", "logs", "speakit-backend.log");
        if (Files.exists(relativeToCurrent) && Files.isRegularFile(relativeToCurrent)) {
            return relativeToCurrent.toFile();
        }

        return null;
    }

    /**
     * Cleans environment variable values that may have trailing inline comments (e.g. "local # coolify" -> "local").
     */
    private String cleanEnv(String val) {
        if (val == null) return "local";
        String trimmed = val.trim();
        if (trimmed.contains("#")) {
            trimmed = trimmed.split("#")[0].trim();
        }
        return trimmed.isEmpty() ? "local" : trimmed;
    }

    private byte[] compressGzip(File file) throws Exception {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (InputStream in = new FileInputStream(file);
             GZIPOutputStream gzipOut = new GZIPOutputStream(baos)) {
            byte[] buffer = new byte[65536]; // 64 KB streaming buffer
            int len;
            while ((len = in.read(buffer)) > 0) {
                gzipOut.write(buffer, 0, len);
            }
            gzipOut.finish();
        }
        return baos.toByteArray();
    }

    /**
     * Finds and uploads any exceeded rollover chunks (*.gz) in the logs directory.
     * Destination key format: speakit-backend/<YYYY>/archive/<filename>.gz
     */
    private java.util.List<String> uploadRolledArchives(File logDir, String safeBucket, String year) {
        java.util.List<String> uploadedKeys = new java.util.ArrayList<>();
        if (logDir == null || !logDir.exists() || !logDir.isDirectory()) {
            return uploadedKeys;
        }

        File[] rolledFiles = logDir.listFiles((dir, name) ->
                name.startsWith("speakit-backend.log.") && name.endsWith(".gz"));

        if (rolledFiles == null || rolledFiles.length == 0) {
            return uploadedKeys;
        }

        for (File chunk : rolledFiles) {
            try {
                String archiveKey = String.format("speakit-backend/%s/archive/%s", year, chunk.getName());
                PutObjectRequest req = PutObjectRequest.builder()
                        .bucket(safeBucket)
                        .key(archiveKey)
                        .contentType("application/gzip")
                        .build();

                s3Client.putObject(req, RequestBody.fromFile(chunk));
                uploadedKeys.add(archiveKey);
                log.info("Uploaded historical/exceeded archive chunk to Cloudflare R2: {} ({} bytes)",
                        archiveKey, chunk.length());
            } catch (Exception e) {
                log.warn("Failed to upload archive chunk {}: {}", chunk.getName(), e.getMessage());
            }
        }
        return uploadedKeys;
    }

    private boolean isConfigured(String val) {
        return val != null && !val.trim().isEmpty();
    }
}
