package com.speakit.notification.service;

import com.speakit.notification.entity.LogBackupAudit;
import com.speakit.notification.repository.LogBackupAuditRepository;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LogBackupAuditServiceTest {

    @Mock
    private LogBackupAuditRepository auditRepository;

    @Mock
    private UserRepository userRepository;

    private LogBackupAuditService auditService;

    @BeforeEach
    void setUp() {
        auditService = new LogBackupAuditService(auditRepository, userRepository);
    }

    @Test
    void recordStart_withUser_persistsInProgressWithUserRef() {
        User dummyUser = User.builder().id(42L).username("testuser").build();
        when(userRepository.getReferenceById(42L)).thenReturn(dummyUser);

        LogBackupAudit savedEntity = LogBackupAudit.builder().id(100L).status("IN_PROGRESS").build();
        when(auditRepository.save(any(LogBackupAudit.class))).thenReturn(savedEntity);

        Long auditId = auditService.recordStart("manual", "testuser", 42L);

        assertEquals(100L, auditId);
        ArgumentCaptor<LogBackupAudit> captor = ArgumentCaptor.forClass(LogBackupAudit.class);
        verify(auditRepository).save(captor.capture());
        LogBackupAudit captured = captor.getValue();
        assertEquals("MANUAL", captured.getTriggerType());
        assertEquals("testuser", captured.getTriggeredBy());
        assertEquals("IN_PROGRESS", captured.getStatus());
        assertEquals(dummyUser, captured.getUser());
    }

    @Test
    void recordStart_scheduledSystem_persistsWithoutUser() {
        LogBackupAudit savedEntity = LogBackupAudit.builder().id(101L).status("IN_PROGRESS").build();
        when(auditRepository.save(any(LogBackupAudit.class))).thenReturn(savedEntity);

        Long auditId = auditService.recordStart("scheduled", "system", null);

        assertEquals(101L, auditId);
        verifyNoInteractions(userRepository);
        ArgumentCaptor<LogBackupAudit> captor = ArgumentCaptor.forClass(LogBackupAudit.class);
        verify(auditRepository).save(captor.capture());
        assertEquals("SCHEDULED", captor.getValue().getTriggerType());
        assertEquals("system", captor.getValue().getTriggeredBy());
        assertNull(captor.getValue().getUser());
    }

    @Test
    void recordSuccess_updatesAuditWithSuccessAndTelemetry() {
        LogBackupAudit existing = LogBackupAudit.builder().id(100L).status("IN_PROGRESS").build();
        when(auditRepository.findById(100L)).thenReturn(Optional.of(existing));

        auditService.recordSuccess(100L, "Cloudflare R2", "speakit-logs", "speakit-backend/2026/active.log.gz",
                "\"etag-123\"", 10000L, 2000L, "80.00%", 3, 250L);

        ArgumentCaptor<LogBackupAudit> captor = ArgumentCaptor.forClass(LogBackupAudit.class);
        verify(auditRepository).save(captor.capture());
        LogBackupAudit updated = captor.getValue();
        assertEquals("SUCCESS", updated.getStatus());
        assertEquals("Cloudflare R2", updated.getStorageProvider());
        assertEquals("speakit-logs", updated.getBucketName());
        assertEquals("speakit-backend/2026/active.log.gz", updated.getObjectKey());
        assertEquals("etag-123", updated.getEtag());
        assertEquals(10000L, updated.getOriginalSizeBytes());
        assertEquals(2000L, updated.getCompressedSizeBytes());
        assertEquals("80.00%", updated.getCompressionRatio());
        assertEquals(3, updated.getArchivedChunksCount());
        assertEquals(250L, updated.getExecutionDurationMs());
    }

    @Test
    void recordFailure_updatesAuditWithFailedAndTruncatedError() {
        LogBackupAudit existing = LogBackupAudit.builder().id(100L).status("IN_PROGRESS").build();
        when(auditRepository.findById(100L)).thenReturn(Optional.of(existing));

        String longError = "E".repeat(1200);
        auditService.recordFailure(100L, "Cloudflare R2", "speakit-logs", "speakit-backend/2026/active.log.gz",
                5000L, longError, 120L);

        ArgumentCaptor<LogBackupAudit> captor = ArgumentCaptor.forClass(LogBackupAudit.class);
        verify(auditRepository).save(captor.capture());
        LogBackupAudit updated = captor.getValue();
        assertEquals("FAILED", updated.getStatus());
        assertEquals(1000, updated.getErrorMessage().length());
        assertTrue(updated.getErrorMessage().endsWith("..."));
        assertEquals(120L, updated.getExecutionDurationMs());
    }

    @Test
    void recordSkipped_updatesAuditWithSkippedAndReason() {
        LogBackupAudit existing = LogBackupAudit.builder().id(100L).status("IN_PROGRESS").build();
        when(auditRepository.findById(100L)).thenReturn(Optional.of(existing));

        auditService.recordSkipped(100L, "Cloudflare R2", "speakit-logs", "No active log file found", 15L);

        ArgumentCaptor<LogBackupAudit> captor = ArgumentCaptor.forClass(LogBackupAudit.class);
        verify(auditRepository).save(captor.capture());
        LogBackupAudit updated = captor.getValue();
        assertEquals("SKIPPED", updated.getStatus());
        assertEquals("No active log file found", updated.getErrorMessage());
        assertEquals(15L, updated.getExecutionDurationMs());
    }
}
