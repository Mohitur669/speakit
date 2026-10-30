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
import java.time.ZoneId;
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

    @Value("${cloudflare.r2.logs.timezone:${TZ:Asia/Kolkata}}")
    private String logTimezone;

    private S3Client s3Client;
    private boolean r2Enabled = false;

    private final LogBackupAuditService auditService;

    private static final DateTimeFormatter YEAR_FORMATTER = DateTimeFormatter.ofPattern("yyyy");
    private static final DateTimeFormatter DAY_MONTH_YEAR_FORMATTER = DateTimeFormatter.ofPattern("dd-MM-yyyy");
    private static final DateTimeFormatter TIMESTAMP_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd_HH-mm-ss");

    public LogBackupService() {
        this.auditService = null;
    }

    @org.springframework.beans.factory.annotation.Autowired
    public LogBackupService(@org.springframework.beans.factory.annotation.Autowired(required = false) LogBackupAuditService auditService) {
        this.auditService = auditService;
    }

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
        return backupActiveLog(trigger, "scheduled".equalsIgnoreCase(trigger) ? "system" : "unknown", null);
    }

    /**
     * Executes backup for active speakit-backend.log with explicit actor tracking.
     *
     * @param trigger     "scheduled" or "manual"
     * @param triggeredBy Actor description (e.g. "system" or "mohitur")
     * @return LogBackupResult telemetry payload
     */
    public LogBackupResult backupActiveLog(String trigger, String triggeredBy) {
        return backupActiveLog(trigger, triggeredBy, null);
    }

    /**
     * Executes backup for active speakit-backend.log with explicit actor and user tracking.
     * Captures transactional IN_PROGRESS, SUCCESS, FAILED, or SKIPPED audit entries.
     *
     * @param trigger     "scheduled" or "manual"
     * @param triggeredBy Actor description (e.g. "system" or "mohitur")
     * @param userId      Database primary key of triggering user, or null if scheduled
     * @return LogBackupResult telemetry payload
     */
    public LogBackupResult backupActiveLog(String trigger, String triggeredBy, Long userId) {
        long startTime = System.currentTimeMillis();
        Instant nowUtc = Instant.now();
        ZoneId zoneId = resolveZoneId();
        ZonedDateTime zdt = nowUtc.atZone(zoneId);

        String safeBucket = (bucketName != null) ? bucketName.trim() : "";

        // 1. Record initial IN_PROGRESS state in audit ledger (commits immediately via REQUIRES_NEW)
        Long auditId = (auditService != null) ? auditService.recordStart(trigger, triggeredBy, userId) : null;

        if (!r2Enabled || s3Client == null) {
            long duration = System.currentTimeMillis() - startTime;
            String msg = "R2 Log Backup is disabled because credentials or bucket name are unconfigured.";
            if (auditService != null) {
                auditService.recordSkipped(auditId, "Cloudflare R2", safeBucket, msg, duration);
            }
            return LogBackupResult.builder()
                    .status("SKIPPED")
                    .auditId(auditId)
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .message(msg)
                    .timestamp(nowUtc)
                    .durationMs(duration)
                    .build();
        }

        File logFile = resolveActiveLogFile();
        if (logFile == null || !logFile.exists() || !logFile.isFile()) {
            long duration = System.currentTimeMillis() - startTime;
            String msg = "No active log file found on disk.";
            log.warn("Active log file not found. Checked locations: coolifyDir='{}', default='logs/speakit-backend.log'", coolifyLogsDir);
            if (auditService != null) {
                auditService.recordSkipped(auditId, "Cloudflare R2", safeBucket, msg, duration);
            }
            return LogBackupResult.builder()
                    .status("SKIPPED")
                    .auditId(auditId)
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .message(msg)
                    .timestamp(nowUtc)
                    .durationMs(duration)
                    .build();
        }

        long originalSizeBytes = logFile.length();
        if (originalSizeBytes == 0) {
            long duration = System.currentTimeMillis() - startTime;
            String msg = "Active log file is currently empty (0 bytes).";
            if (auditService != null) {
                auditService.recordSkipped(auditId, "Cloudflare R2", safeBucket, msg, duration);
            }
            return LogBackupResult.builder()
                    .status("SKIPPED")
                    .auditId(auditId)
                    .trigger(trigger)
                    .triggeredBy(triggeredBy)
                    .storageProvider("Cloudflare R2")
                    .bucket(safeBucket)
                    .message(msg)
                    .timestamp(nowUtc)
                    .durationMs(duration)
                    .build();
        }

        String year = zdt.format(YEAR_FORMATTER);
        String dayMonthYear = zdt.format(DAY_MONTH_YEAR_FORMATTER);
        String timestamp = zdt.format(TIMESTAMP_FORMATTER);
        // Destination format: <bucket_name>/speakit-backend/<YYYY>/<DD-MM-YYYY>/speakit-backend-<trigger>-<TIMESTAMP>.log.gz
        String activeObjectKey = String.format("speakit-backend/%s/%s/speakit-backend-%s-%s.log.gz", year, dayMonthYear, trigger, timestamp);

        try {
            // 2. In-memory streaming gzip compression of active log
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

            // 3. Sync any historical/exceeded chunks (*.gz) to <bucket_name>/speakit-backend/<YYYY>/<DD-MM-YYYY>/archive/<chunk_name>.gz
            java.util.List<String> archivedKeys = uploadRolledArchives(logFile.getParentFile(), safeBucket, year, dayMonthYear);

            long duration = System.currentTimeMillis() - startTime;
            int totalFiles = 1 + archivedKeys.size();
            String sanitizedEtag = cleanEtag(response.eTag());
            log.info("Successfully uploaded active log snapshot and {} rolled chunks to Cloudflare R2: {} ({} -> {} bytes, -{}, {}ms, triggeredBy: {})",
                    archivedKeys.size(), activeObjectKey, originalSizeBytes, compressedSizeBytes, compressionRatioStr, duration, triggeredBy);

            // 4. Update audit record to SUCCESS in audit ledger
            if (auditService != null) {
                auditService.recordSuccess(auditId, "Cloudflare R2", safeBucket, activeObjectKey, sanitizedEtag,
                        originalSizeBytes, compressedSizeBytes, compressionRatioStr, archivedKeys.size(), duration);
            }

            return LogBackupResult.builder()
                    .status("SUCCESS")
                    .auditId(auditId)
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
                    .eTag(sanitizedEtag)
                    .message(String.format("Log snapshot and %d exceeded archive chunk(s) successfully backed up to Cloudflare R2.", archivedKeys.size()))
                    .timestamp(nowUtc)
                    .build();

        } catch (Exception e) {
            long duration = System.currentTimeMillis() - startTime;
            log.error("Failed to backup log to Cloudflare R2: {}", e.getMessage(), e);

            // 5. Update audit record to FAILED in audit ledger
            if (auditService != null) {
                auditService.recordFailure(auditId, "Cloudflare R2", safeBucket, activeObjectKey, originalSizeBytes, e.getMessage(), duration);
            }

            return LogBackupResult.builder()
                    .status("FAILED")
                    .auditId(auditId)
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
     * Destination key format: speakit-backend/<YYYY>/<DD-MM-YYYY>/archive/<filename>.gz
     */
    private java.util.List<String> uploadRolledArchives(File logDir, String safeBucket, String year, String dayMonthYear) {
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
                String archiveKey = String.format("speakit-backend/%s/%s/archive/%s", year, dayMonthYear, chunk.getName());
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

    /**
     * Strips enclosing escaped or literal double quotes from HTTP ETag headers.
     * e.g. "\"e12c239c...\"" -> "e12c239c..."
     */
    private String cleanEtag(String rawEtag) {
        if (rawEtag == null) return null;
        return rawEtag.replace("\"", "").trim();
    }

    /**
     * Resolves the configured ZoneId for date and timestamp partitioning.
     * Defaults to Asia/Kolkata if unconfigured or invalid.
     */
    private ZoneId resolveZoneId() {
        if (isConfigured(logTimezone)) {
            try {
                return ZoneId.of(cleanEnv(logTimezone));
            } catch (Exception e) {
                log.warn("Invalid timezone '{}' specified for log backup. Falling back to Asia/Kolkata.", logTimezone);
            }
        }
        return ZoneId.of("Asia/Kolkata");
    }
}
