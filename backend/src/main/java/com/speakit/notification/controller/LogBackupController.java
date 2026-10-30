package com.speakit.notification.controller;

import com.speakit.notification.dto.LogBackupResult;
import com.speakit.notification.service.LogBackupService;
import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.security.Principal;

/**
 * Controller for administrative log backup operations.
 *
 * Security:
 * - Protected by Spring Security JWT authentication.
 * - Rate limited under RateLimitAction.PUBLIC to prevent resource abuse.
 */
@RestController
@RequestMapping("/api/admin/logs")
@Slf4j
public class LogBackupController {

    private final LogBackupService logBackupService;

    public LogBackupController(LogBackupService logBackupService) {
        this.logBackupService = logBackupService;
    }

    /**
     * Triggers a manual snapshot of the active speakit-backend.log, compresses it,
     * and uploads it to Cloudflare R2 for disaster recovery or ad-hoc verification.
     *
     * @param request HTTP request containing authenticated user attributes
     * @return LogBackupResult with upload telemetry, compression ratios, and R2 object key
     */
    @PostMapping("/backup")
    @RateLimited(action = RateLimitAction.PUBLIC)
    public ResponseEntity<LogBackupResult> triggerManualBackup(HttpServletRequest request, Principal principal) {
        Object userId = request.getAttribute("userId");
        String username = (principal != null && principal.getName() != null) ? principal.getName() : "authenticated-user";

        log.info("Manual log backup triggered by user: {} (username: '{}')", userId, username);

        LogBackupResult result = logBackupService.backupActiveLog("manual", username);

        if ("FAILED".equalsIgnoreCase(result.getStatus())) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(result);
        }

        return ResponseEntity.ok(result);
    }
}
