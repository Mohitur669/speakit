package com.speakit.notification.controller;

import com.speakit.notification.dto.LogBackupResult;
import com.speakit.notification.service.LogBackupService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;

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
                .status("SUCCESS")
                .trigger("manual")
                .triggeredBy("mohitur")
                .bucket("speakit-logs")
                .objectKey("speakit-backend/speakit-backend-manual-2026-10-31_00-00-00.log.gz")
                .build();

        when(logBackupService.backupActiveLog(eq("manual"), eq("mohitur"), eq(42L))).thenReturn(expectedResult);

        ResponseEntity<LogBackupResult> response = logBackupController.triggerManualBackup(request, principal);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("SUCCESS", response.getBody().getStatus());
        assertEquals("manual", response.getBody().getTrigger());
        assertEquals("mohitur", response.getBody().getTriggeredBy());
        verify(logBackupService, times(1)).backupActiveLog("manual", "mohitur", 42L);
    }

    @Test
    void triggerManualBackup_whenFailed_returns500InternalServerError() {
        when(request.getAttribute("userId")).thenReturn(42L);
        when(principal.getName()).thenReturn("mohitur");

        LogBackupResult failedResult = LogBackupResult.builder()
                .status("FAILED")
                .trigger("manual")
                .triggeredBy("mohitur")
                .message("R2 PutObject connection timeout")
                .build();

        when(logBackupService.backupActiveLog(eq("manual"), eq("mohitur"), eq(42L))).thenReturn(failedResult);

        ResponseEntity<LogBackupResult> response = logBackupController.triggerManualBackup(request, principal);

        assertEquals(HttpStatus.INTERNAL_SERVER_ERROR, response.getStatusCode());
        assertEquals("FAILED", response.getBody().getStatus());
        assertEquals("mohitur", response.getBody().getTriggeredBy());
        verify(logBackupService, times(1)).backupActiveLog("manual", "mohitur", 42L);
    }
}
