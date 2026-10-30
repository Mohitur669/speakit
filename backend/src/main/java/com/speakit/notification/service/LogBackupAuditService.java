package com.speakit.notification.service;

import com.speakit.notification.entity.LogBackupAudit;
import com.speakit.notification.repository.LogBackupAuditRepository;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service managing transactional audit lifecycle state transitions for Cloudflare R2 log backups.
 * Uses REQUIRES_NEW propagation so initial IN_PROGRESS state commits immediately,
 * guaranteeing audit trail persistence even if downstream storage uploads fail or terminate.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class LogBackupAuditService {

    private final LogBackupAuditRepository auditRepository;
    private final UserRepository userRepository;

    /**
     * Records the initial IN_PROGRESS audit state before backup execution begins.
     * Commits immediately in an isolated transaction.
     *
     * @param triggerType 'SCHEDULED' or 'MANUAL'
     * @param triggeredBy Actor identifier (e.g. 'system' or username)
     * @param userId      Database primary key of triggering user, or null if scheduled
     * @return Generated audit record ID, or null if database recording encounters an error
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public Long recordStart(String triggerType, String triggeredBy, Long userId) {
        try {
            User userRef = null;
            if (userId != null) {
                userRef = userRepository.getReferenceById(userId);
            }

            LogBackupAudit audit = LogBackupAudit.builder()
                    .triggerType(triggerType != null ? triggerType.toUpperCase() : "MANUAL")
                    .triggeredBy(triggeredBy != null ? triggeredBy : "unknown")
                    .user(userRef)
                    .status("IN_PROGRESS")
                    .archivedChunksCount(0)
                    .build();

            LogBackupAudit saved = auditRepository.save(audit);
            log.info("Initialized log backup audit record ID: {} (trigger: {}, by: {})", saved.getId(), triggerType, triggeredBy);
            return saved.getId();
        } catch (Exception e) {
            log.error("Failed to persist initial IN_PROGRESS log backup audit record: {}", e.getMessage(), e);
            return null;
        }
    }

    /**
     * Marks the audit record as SUCCESS and records final telemetry metrics.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordSuccess(Long auditId, String storageProvider, String bucketName, String objectKey,
                              String etag, long originalBytes, long compressedBytes, String compressionRatio,
                              int archivedChunksCount, long durationMs) {
        if (auditId == null) {
            return;
        }

        try {
            auditRepository.findById(auditId).ifPresent(audit -> {
                audit.setStatus("SUCCESS");
                audit.setStorageProvider(storageProvider);
                audit.setBucketName(bucketName);
                audit.setObjectKey(objectKey);
                audit.setEtag(cleanEtag(etag));
                audit.setOriginalSizeBytes(originalBytes);
                audit.setCompressedSizeBytes(compressedBytes);
                audit.setCompressionRatio(compressionRatio);
                audit.setArchivedChunksCount(archivedChunksCount);
                audit.setExecutionDurationMs(durationMs);
                auditRepository.save(audit);
                log.info("Completed log backup audit record ID: {} with status SUCCESS (duration: {}ms, key: {})",
                        auditId, durationMs, objectKey);
            });
        } catch (Exception e) {
            log.error("Failed to update log backup audit record ID {} to SUCCESS: {}", auditId, e.getMessage(), e);
        }
    }

    /**
     * Marks the audit record as FAILED and captures the root-cause failure reason.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordFailure(Long auditId, String storageProvider, String bucketName, String objectKey,
                              long originalBytes, String errorMessage, long durationMs) {
        if (auditId == null) {
            return;
        }

        try {
            auditRepository.findById(auditId).ifPresent(audit -> {
                audit.setStatus("FAILED");
                audit.setStorageProvider(storageProvider);
                audit.setBucketName(bucketName);
                audit.setObjectKey(objectKey);
                audit.setOriginalSizeBytes(originalBytes > 0 ? originalBytes : null);
                audit.setExecutionDurationMs(durationMs);

                String safeError = errorMessage;
                if (safeError != null && safeError.length() > 1000) {
                    safeError = safeError.substring(0, 997) + "...";
                }
                audit.setErrorMessage(safeError);

                auditRepository.save(audit);
                log.warn("Updated log backup audit record ID: {} with status FAILED: {}", auditId, safeError);
            });
        } catch (Exception e) {
            log.error("Failed to update log backup audit record ID {} to FAILED: {}", auditId, e.getMessage(), e);
        }
    }

    /**
     * Marks the audit record as SKIPPED when pre-flight checks fail (e.g. empty log or unconfigured credentials).
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void recordSkipped(Long auditId, String storageProvider, String bucketName, String reason, long durationMs) {
        if (auditId == null) {
            return;
        }

        try {
            auditRepository.findById(auditId).ifPresent(audit -> {
                audit.setStatus("SKIPPED");
                audit.setStorageProvider(storageProvider);
                audit.setBucketName(bucketName);
                audit.setExecutionDurationMs(durationMs);

                String safeReason = reason;
                if (safeReason != null && safeReason.length() > 1000) {
                    safeReason = safeReason.substring(0, 997) + "...";
                }
                audit.setErrorMessage(safeReason);

                auditRepository.save(audit);
                log.info("Updated log backup audit record ID: {} with status SKIPPED: {}", auditId, safeReason);
            });
        } catch (Exception e) {
            log.error("Failed to update log backup audit record ID {} to SKIPPED: {}", auditId, e.getMessage(), e);
        }
    }

    private String cleanEtag(String rawEtag) {
        if (rawEtag == null) return null;
        return rawEtag.replace("\"", "").trim();
    }
}
