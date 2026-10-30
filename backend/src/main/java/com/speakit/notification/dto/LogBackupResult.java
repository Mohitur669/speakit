package com.speakit.notification.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;

/**
 * Telemetry response returned after a scheduled or manual log backup to Cloudflare R2.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class LogBackupResult {

    private String status;           // SUCCESS, SKIPPED, FAILED
    private Long auditId;            // Database primary key of the audit record
    private String trigger;          // scheduled, manual
    private String triggeredBy;      // system, username (id: 1)
    private String storageProvider;  // Cloudflare R2
    private String bucket;
    private String objectKey;
    private java.util.List<String> archivedChunksUploaded;
    private int totalFilesUploaded;
    private long originalSizeBytes;
    private long compressedSizeBytes;
    private String compressionRatio;
    private long durationMs;
    private String eTag;
    private String message;
    private Instant timestamp;
}
