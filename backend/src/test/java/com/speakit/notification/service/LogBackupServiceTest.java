package com.speakit.notification.service;

import com.speakit.notification.dto.LogBackupResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.api.io.TempDir;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.test.util.ReflectionTestUtils;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectResponse;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Request;
import software.amazon.awssdk.services.s3.model.ListObjectsV2Response;
import software.amazon.awssdk.services.s3.model.S3Object;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;
import software.amazon.awssdk.core.ResponseInputStream;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LogBackupServiceTest {

    @Mock
    private S3Client s3Client;

    @Mock
    private LogBackupAuditService auditService;

    private LogBackupService logBackupService;

    @BeforeEach
    void setUp() {
        logBackupService = new LogBackupService(auditService);
    }

    @Test
    void init_whenCredentialsMissing_disablesService() {
        ReflectionTestUtils.setField(logBackupService, "accountId", "");
        ReflectionTestUtils.setField(logBackupService, "bucketName", "");
        assertDoesNotThrow(() -> logBackupService.init());
        assertFalse((Boolean) ReflectionTestUtils.getField(logBackupService, "r2Enabled"));
    }

    @Test
    void backupActiveLog_whenDisabled_returnsSkippedResult() {
        ReflectionTestUtils.setField(logBackupService, "r2Enabled", false);
        LogBackupResult result = logBackupService.backupActiveLog("manual");
        assertEquals("Skipped", result.getStatus());
        assertEquals("Manual", result.getTrigger());
        assertTrue(result.getMessage().contains("disabled"));
    }

    @Test
    void backupActiveLog_whenNoLogFileFound_returnsSkippedResult() {
        ReflectionTestUtils.setField(logBackupService, "r2Enabled", true);
        ReflectionTestUtils.setField(logBackupService, "s3Client", s3Client);
        ReflectionTestUtils.setField(logBackupService, "logEnvironment", "coolify");
        ReflectionTestUtils.setField(logBackupService, "coolifyLogsDir", "/non/existent/path/logs");

        LogBackupResult result = logBackupService.backupActiveLog("manual");
        assertEquals("Skipped", result.getStatus());
        assertTrue(result.getMessage().contains("No active log file found"));
    }

    @Test
    void backupActiveLog_whenValidLogFileInLocalEnv_compressesAndUploadsSuccessfully(@TempDir Path tempDir) throws Exception {
        File dummyLog = tempDir.resolve("speakit-backend.log").toFile();
        try (FileOutputStream fos = new FileOutputStream(dummyLog)) {
            fos.write("2026-10-31 00:00:00.000 INFO [speakit-backend] : Application health check OK\n".repeat(100)
                    .getBytes(StandardCharsets.UTF_8));
        }

        ReflectionTestUtils.setField(logBackupService, "r2Enabled", true);
        ReflectionTestUtils.setField(logBackupService, "s3Client", s3Client);
        ReflectionTestUtils.setField(logBackupService, "bucketName", "test-log-bucket");
        ReflectionTestUtils.setField(logBackupService, "logEnvironment", "local # coolify");
        ReflectionTestUtils.setField(logBackupService, "localLogsDir", dummyLog.getAbsolutePath());

        PutObjectResponse mockResponse = PutObjectResponse.builder().eTag("\"test-etag-123\"").build();
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class))).thenReturn(mockResponse);
        when(auditService.recordStart(eq("Upload"), eq("Scheduled"), eq("system"), isNull())).thenReturn(999L);

        LogBackupResult result = logBackupService.backupActiveLog("scheduled");

        assertEquals("Completed", result.getStatus());
        assertEquals(999L, result.getAuditId());
        assertEquals("Scheduled", result.getTrigger());
        assertEquals("test-log-bucket", result.getBucket());
        assertEquals("test-etag-123", result.getETag());
        assertTrue(result.getObjectKey().matches("^speakit-backend/\\d{4}/\\d{2}-\\d{2}-\\d{4}/speakit-backend-scheduled-.*\\.log\\.gz$"));
        assertTrue(result.getCompressedSizeBytes() > 0);
        assertTrue(result.getCompressedSizeBytes() < result.getOriginalSizeBytes());

        verify(s3Client, times(1)).putObject(any(PutObjectRequest.class), any(RequestBody.class));
        verify(auditService).recordStart(eq("Upload"), eq("Scheduled"), eq("system"), isNull());
        verify(auditService).recordSuccess(eq(999L), eq("Cloudflare R2"), eq("test-log-bucket"), eq(result.getObjectKey()),
                eq("test-etag-123"), eq(result.getOriginalSizeBytes()), eq(result.getCompressedSizeBytes()),
                eq(result.getCompressionRatio()), eq(0), anyLong());
    }

    @Test
    void backupActiveLog_whenValidLogFileInCoolifyEnv_compressesAndUploadsSuccessfully(@TempDir Path tempDir) throws Exception {
        File dummyLog = tempDir.resolve("speakit-backend.log").toFile();
        try (FileOutputStream fos = new FileOutputStream(dummyLog)) {
            fos.write("2026-10-31 00:00:00.000 INFO [speakit-backend] : Coolify health check OK\n".repeat(100)
                    .getBytes(StandardCharsets.UTF_8));
        }

        // Also create a dummy rolled archive chunk to test multi-chunk sync
        File dummyRolled = tempDir.resolve("speakit-backend.log.2026-10-31.0.gz").toFile();
        try (FileOutputStream fos = new FileOutputStream(dummyRolled)) {
            fos.write("dummy-rolled-gz-content".getBytes(StandardCharsets.UTF_8));
        }

        ReflectionTestUtils.setField(logBackupService, "r2Enabled", true);
        ReflectionTestUtils.setField(logBackupService, "s3Client", s3Client);
        ReflectionTestUtils.setField(logBackupService, "bucketName", "test-log-bucket");
        ReflectionTestUtils.setField(logBackupService, "logEnvironment", "coolify");
        ReflectionTestUtils.setField(logBackupService, "coolifyLogsDir", dummyLog.getAbsolutePath());

        PutObjectResponse mockResponse = PutObjectResponse.builder().eTag("\"coolify-etag-456\"").build();
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class))).thenReturn(mockResponse);

        LogBackupResult result = logBackupService.backupActiveLog("manual");

        assertEquals("Completed", result.getStatus());
        assertEquals("Manual", result.getTrigger());
        assertEquals("test-log-bucket", result.getBucket());
        assertEquals("coolify-etag-456", result.getETag());
        assertTrue(result.getObjectKey().matches("^speakit-backend/\\d{4}/\\d{2}-\\d{2}-\\d{4}/speakit-backend-manual-.*\\.log\\.gz$"));
        assertEquals(2, result.getTotalFilesUploaded());
        assertNotNull(result.getArchivedChunksUploaded());
        assertEquals(1, result.getArchivedChunksUploaded().size());
        assertTrue(result.getArchivedChunksUploaded().get(0).matches("^speakit-backend/\\d{4}/\\d{2}-\\d{2}-\\d{4}/archive/speakit-backend\\.log\\.2026-10-31\\.0\\.gz$"));
    }

    @Test
    void backupActiveLog_whenS3Fails_recordsFailureAndReturnsFailedResult(@TempDir Path tempDir) throws Exception {
        File dummyLog = tempDir.resolve("speakit-backend.log").toFile();
        try (FileOutputStream fos = new FileOutputStream(dummyLog)) {
            fos.write("dummy-log-content".getBytes(StandardCharsets.UTF_8));
        }

        ReflectionTestUtils.setField(logBackupService, "r2Enabled", true);
        ReflectionTestUtils.setField(logBackupService, "s3Client", s3Client);
        ReflectionTestUtils.setField(logBackupService, "bucketName", "test-log-bucket");
        ReflectionTestUtils.setField(logBackupService, "localLogsDir", dummyLog.getAbsolutePath());

        when(auditService.recordStart(eq("Upload"), eq("Manual"), eq("mohitur"), eq(10L))).thenReturn(500L);
        when(s3Client.putObject(any(PutObjectRequest.class), any(RequestBody.class)))
                .thenThrow(new RuntimeException("Simulated R2 network timeout"));

        LogBackupResult result = logBackupService.backupActiveLog("manual", "mohitur", 10L);

        assertEquals("Failed", result.getStatus());
        assertEquals(500L, result.getAuditId());
        assertTrue(result.getMessage().contains("Simulated R2 network timeout"));
        verify(auditService).recordFailure(eq(500L), eq("Cloudflare R2"), eq("test-log-bucket"), anyString(),
                anyLong(), contains("Simulated R2 network timeout"), anyLong());
    }

    @Test
    void findLogKeysForRange_scansDatesAndFiltersGzFiles() {
        ReflectionTestUtils.setField(logBackupService, "r2Enabled", true);
        ReflectionTestUtils.setField(logBackupService, "s3Client", s3Client);
        ReflectionTestUtils.setField(logBackupService, "bucketName", "test-log-bucket");

        S3Object obj1 = S3Object.builder().key("speakit-backend/2026/30-10-2026/speakit-backend-manual-2026-10-30_12-00-00.log.gz").build();
        S3Object objNonGz = S3Object.builder().key("speakit-backend/2026/30-10-2026/ignored.txt").build();
        ListObjectsV2Response listResp1 = ListObjectsV2Response.builder().contents(obj1, objNonGz).build();

        S3Object obj2 = S3Object.builder().key("speakit-backend/2026/31-10-2026/speakit-backend-scheduled-2026-10-31_00-00-00.log.gz").build();
        ListObjectsV2Response listResp2 = ListObjectsV2Response.builder().contents(obj2).build();

        when(s3Client.listObjectsV2(any(ListObjectsV2Request.class)))
                .thenReturn(listResp1)
                .thenReturn(listResp2);

        LocalDate start = LocalDate.of(2026, 10, 30);
        LocalDate end = LocalDate.of(2026, 10, 31);

        List<String> keys = logBackupService.findLogKeysForRange(start, end);

        assertEquals(2, keys.size());
        assertTrue(keys.contains("speakit-backend/2026/30-10-2026/speakit-backend-manual-2026-10-30_12-00-00.log.gz"));
        assertTrue(keys.contains("speakit-backend/2026/31-10-2026/speakit-backend-scheduled-2026-10-31_00-00-00.log.gz"));
        assertFalse(keys.contains("speakit-backend/2026/30-10-2026/ignored.txt"));
    }

    @Test
    void createZipStream_streamsEntriesAndRecordsAuditSuccess() throws Exception {
        ReflectionTestUtils.setField(logBackupService, "s3Client", s3Client);
        ReflectionTestUtils.setField(logBackupService, "bucketName", "test-log-bucket");

        String key = "speakit-backend/2026/31-10-2026/speakit-backend-manual-2026-10-31_12-00-00.log.gz";
        byte[] dummyGzContent = "fake-gzip-content-stream".getBytes(StandardCharsets.UTF_8);

        GetObjectResponse getResponse = GetObjectResponse.builder().build();
        ResponseInputStream<GetObjectResponse> s3Stream =
                new ResponseInputStream<>(getResponse, new ByteArrayInputStream(dummyGzContent));
        when(s3Client.getObject(any(GetObjectRequest.class))).thenReturn(s3Stream);

        StreamingResponseBody stream = logBackupService.createZipStream(
                List.of(key), "speakit-logs-test.zip", "mohitur", 777L);

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        stream.writeTo(out);

        assertTrue(out.size() > 0);
        verify(auditService).recordSuccess(eq(777L), eq("Cloudflare R2"), eq("test-log-bucket"),
                eq("speakit-logs-test.zip"), isNull(), anyLong(), anyLong(), eq("0.00%"), eq(1), anyLong());
    }
}
