package com.speakit.notification.controller;

import com.speakit.notification.dto.LogBackupResult;
import com.speakit.notification.service.LogBackupService;
import com.speakit.shared.exception.GlobalExceptionHandler;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.asyncDispatch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@ExtendWith(MockitoExtension.class)
class LogBackupControllerTest {

    @Mock
    private LogBackupService logBackupService;

    @Mock
    private HttpServletRequest request;

    @Mock
    private java.security.Principal principal;

    private LogBackupController logBackupController;

    @BeforeEach
    void setUp() {
        logBackupController = new LogBackupController(logBackupService);
    }

    @Test
    void triggerManualBackup_whenSuccess_returns200Ok() {
        when(request.getAttribute("userId")).thenReturn(42L);
        when(principal.getName()).thenReturn("mohitur");

        LogBackupResult expectedResult = LogBackupResult.builder()
                .status("Completed")
                .trigger("Manual")
                .triggeredBy("mohitur")
                .bucket("speakit-logs")
                .objectKey("speakit-backend/speakit-backend-manual-2026-10-31_00-00-00.log.gz")
                .build();

        when(logBackupService.backupActiveLog(eq("manual"), eq("mohitur"), eq(42L))).thenReturn(expectedResult);

        ResponseEntity<LogBackupResult> response = logBackupController.triggerManualBackup(request, principal);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("Completed", response.getBody().getStatus());
        assertEquals("Manual", response.getBody().getTrigger());
        assertEquals("mohitur", response.getBody().getTriggeredBy());
        verify(logBackupService, times(1)).backupActiveLog("manual", "mohitur", 42L);
    }

    @Test
    void triggerManualBackup_whenFailed_returns500InternalServerError() {
        when(request.getAttribute("userId")).thenReturn(42L);
        when(principal.getName()).thenReturn("mohitur");

        LogBackupResult failedResult = LogBackupResult.builder()
                .status("Failed")
                .trigger("Manual")
                .triggeredBy("mohitur")
                .message("R2 PutObject connection timeout")
                .build();

        when(logBackupService.backupActiveLog(eq("manual"), eq("mohitur"), eq(42L))).thenReturn(failedResult);

        ResponseEntity<LogBackupResult> response = logBackupController.triggerManualBackup(request, principal);

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertEquals("Failed", response.getBody().getStatus());
        assertEquals("mohitur", response.getBody().getTriggeredBy());
        verify(logBackupService, times(1)).backupActiveLog("manual", "mohitur", 42L);
    }

    @Test
    void downloadLogs_whenInvalidDateFormat_throwsException() {
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                logBackupController.downloadLogs("invalid-date", "31-10-2026", request, principal)
        );
        assertTrue(ex.getMessage().contains("Invalid date format"));
    }

    @Test
    void downloadLogs_whenStartDateAfterEndDate_throwsException() {
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                logBackupController.downloadLogs("31-10-2026", "24-10-2026", request, principal)
        );
        assertTrue(ex.getMessage().contains("endDate cannot be before startDate"));
    }

    @Test
    void downloadLogs_whenDateRangeExceeds7Days_throwsException() {
        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                logBackupController.downloadLogs("01-10-2026", "15-10-2026", request, principal)
        );
        assertTrue(ex.getMessage().contains("exceeds maximum limit of 7 days"));
    }

    @Test
    void downloadLogs_whenEndDateInFuture_throwsException() {
        when(logBackupService.getZoneId()).thenReturn(ZoneId.of("Asia/Kolkata"));
        LocalDate futureDate = LocalDate.now(ZoneId.of("Asia/Kolkata")).plusDays(2);
        String futureStr = futureDate.format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));
        String startStr = futureDate.minusDays(3).format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                logBackupController.downloadLogs(startStr, futureStr, request, principal)
        );
        assertTrue(ex.getMessage().contains("cannot be in the future"));
    }

    @Test
    void downloadLogs_whenR2Disabled_throwsResponseStatusException() {
        when(logBackupService.getZoneId()).thenReturn(ZoneId.of("Asia/Kolkata"));
        when(logBackupService.isR2Enabled()).thenReturn(false);

        LocalDate today = LocalDate.now(ZoneId.of("Asia/Kolkata"));
        String endStr = today.format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));
        String startStr = today.minusDays(2).format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                logBackupController.downloadLogs(startStr, endStr, request, principal)
        );
        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, ex.getStatusCode());
    }

    @Test
    void downloadLogs_whenNoLogsFound_throwsResponseStatusException() {
        when(logBackupService.getZoneId()).thenReturn(ZoneId.of("Asia/Kolkata"));
        when(logBackupService.isR2Enabled()).thenReturn(true);

        LocalDate today = LocalDate.now(ZoneId.of("Asia/Kolkata"));
        String endStr = today.format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));
        String startStr = today.minusDays(2).format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));

        when(logBackupService.findLogKeysForRange(any(LocalDate.class), any(LocalDate.class))).thenReturn(List.of());

        ResponseStatusException ex = assertThrows(ResponseStatusException.class, () ->
                logBackupController.downloadLogs(startStr, endStr, request, principal)
        );
        assertEquals(HttpStatus.NOT_FOUND, ex.getStatusCode());
        assertTrue(ex.getReason().contains("No log backups found"));
    }

    @Test
    void downloadLogs_whenLogsFound_returns200OkWithZipStream() {
        when(request.getAttribute("userId")).thenReturn(42L);
        when(principal.getName()).thenReturn("mohitur");
        when(logBackupService.getZoneId()).thenReturn(ZoneId.of("Asia/Kolkata"));
        when(logBackupService.isR2Enabled()).thenReturn(true);

        LocalDate today = LocalDate.now(ZoneId.of("Asia/Kolkata"));
        String endStr = today.format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));
        String startStr = today.minusDays(2).format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));

        List<String> mockKeys = List.of("speakit-backend/2026/31-10-2026/speakit-backend-manual-2026-10-31_00-00-00.log.gz");
        when(logBackupService.findLogKeysForRange(any(LocalDate.class), any(LocalDate.class))).thenReturn(mockKeys);
        when(logBackupService.recordDownloadAuditStart("mohitur", 42L)).thenReturn(888L);
        StreamingResponseBody mockStream = outputStream -> outputStream.write("ZIPDATA".getBytes());
        when(logBackupService.createZipStream(eq(mockKeys), anyString(), eq("mohitur"), eq(888L))).thenReturn(mockStream);

        ResponseEntity<StreamingResponseBody> response = logBackupController.downloadLogs(startStr, endStr, request, principal);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("application/zip", response.getHeaders().getContentType().toString());
        assertTrue(response.getHeaders().getFirst("Content-Disposition").contains("attachment; filename="));
        assertNotNull(response.getBody());
    }

    @Test
    void downloadLogs_viaMockMvc_dispatchesStreamingResponseBodyWithoutNoConverterError() throws Exception {
        MockMvc mockMvc = MockMvcBuilders.standaloneSetup(logBackupController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        LocalDate today = LocalDate.now(ZoneId.of("Asia/Kolkata"));
        String endStr = today.format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));
        String startStr = today.minusDays(2).format(java.time.format.DateTimeFormatter.ofPattern("dd-MM-yyyy"));

        List<String> mockKeys = List.of("speakit-backend/2026/31-10-2026/test.log.gz");
        when(logBackupService.getZoneId()).thenReturn(ZoneId.of("Asia/Kolkata"));
        when(logBackupService.isR2Enabled()).thenReturn(true);
        when(logBackupService.findLogKeysForRange(any(LocalDate.class), any(LocalDate.class))).thenReturn(mockKeys);
        when(logBackupService.recordDownloadAuditStart(anyString(), any())).thenReturn(999L);
        when(logBackupService.createZipStream(eq(mockKeys), anyString(), anyString(), eq(999L)))
                .thenReturn(out -> out.write(new byte[]{0x50, 0x4B, 0x03, 0x04}));

        MvcResult mvcResult = mockMvc.perform(get("/api/admin/logs/download")
                        .param("startDate", startStr)
                        .param("endDate", endStr))
                .andExpect(request().asyncStarted())
                .andReturn();

        mockMvc.perform(asyncDispatch(mvcResult))
                .andExpect(status().isOk())
                .andExpect(header().string("Content-Type", "application/zip"))
                .andExpect(header().exists("Content-Disposition"))
                .andExpect(content().bytes(new byte[]{0x50, 0x4B, 0x03, 0x04}));
    }

    @Test
    void downloadLogs_viaMockMvc_whenInvalidDate_returnsStructuredJsonError() throws Exception {
        MockMvc mockMvc = MockMvcBuilders.standaloneSetup(logBackupController)
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();

        mockMvc.perform(get("/api/admin/logs/download")
                        .param("startDate", "invalid-date")
                        .param("endDate", "31-10-2026"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400))
                .andExpect(jsonPath("$.error").value("Bad Request"))
                .andExpect(jsonPath("$.message").value("Invalid date format. Expected format is DD-MM-YYYY (e.g. 24-10-2026)."));
    }
}
