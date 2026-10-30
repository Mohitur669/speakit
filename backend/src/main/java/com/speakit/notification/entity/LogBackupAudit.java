package com.speakit.notification.entity;

import com.speakit.shared.entity.BaseEntity;
import com.speakit.user.entity.User;
import jakarta.persistence.*;
import lombok.*;
import lombok.experimental.SuperBuilder;

/**
 * Audit ledger entity capturing the full lifecycle of automated midnight
 * and manual disaster-recovery log backups to Cloudflare R2.
 */
@Entity
@Table(name = "log_backup_audits", indexes = {
    @Index(name = "idx_log_backup_audits_user_id", columnList = "user_id"),
    @Index(name = "idx_log_backup_audits_status", columnList = "status"),
    @Index(name = "idx_log_backup_audits_created_at", columnList = "created_at"),
    @Index(name = "idx_log_backup_audits_trigger", columnList = "trigger_type, status")
})
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@SuperBuilder
public class LogBackupAudit extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "log_backup_audit_seq")
    @SequenceGenerator(
        name = "log_backup_audit_seq",
        sequenceName = "log_backup_audit_seq",
        allocationSize = 50
    )
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;

    @Column(name = "trigger_type", nullable = false, length = 20)
    private String triggerType; // "SCHEDULED" or "MANUAL"

    @Column(name = "triggered_by", nullable = false, length = 100)
    private String triggeredBy; // "system" or username

    @Column(name = "status", nullable = false, length = 20)
    private String status; // "IN_PROGRESS", "SUCCESS", "FAILED", "SKIPPED"

    @Column(name = "storage_provider", length = 50)
    private String storageProvider; // "Cloudflare R2"

    @Column(name = "bucket_name", length = 100)
    private String bucketName;

    @Column(name = "object_key", length = 500)
    private String objectKey;

    @Column(name = "etag", length = 100)
    private String etag;

    @Column(name = "original_size_bytes")
    private Long originalSizeBytes;

    @Column(name = "compressed_size_bytes")
    private Long compressedSizeBytes;

    @Column(name = "compression_ratio", length = 20)
    private String compressionRatio;

    @Column(name = "archived_chunks_count", nullable = false)
    @Builder.Default
    private Integer archivedChunksCount = 0;

    @Column(name = "execution_duration_ms")
    private Long executionDurationMs;

    @Column(name = "error_message", length = 1000)
    private String errorMessage;
}
