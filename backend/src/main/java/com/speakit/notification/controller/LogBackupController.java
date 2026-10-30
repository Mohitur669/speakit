package com.speakit.notification.controller;

import com.speakit.notification.dto.LogBackupResult;
import com.speakit.notification.service.LogBackupService;
import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.web.servlet.mvc.method.annotation.StreamingResponseBody;

import java.security.Principal;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Map;

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
        Object userIdObj = request.getAttribute("userId");
        Long userId = null;
        if (userIdObj instanceof Long) {
            userId = (Long) userIdObj;
        } else if (userIdObj instanceof String) {
            try {
                userId = Long.parseLong((String) userIdObj);
            } catch (NumberFormatException ignored) {
            }
        }
        String username = (principal != null && principal.getName() != null) ? principal.getName() : "authenticated-user";

        log.info("Manual log backup triggered by user: {} (username: '{}')", userId, username);

        LogBackupResult result = logBackupService.backupActiveLog("manual", username, userId);

        if ("Failed".equalsIgnoreCase(result.getStatus())) {
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(result);
        }

        return ResponseEntity.ok(result);
    }

    /**
     * Downloads an on-the-fly compressed ZIP archive of log backups from Cloudflare R2
     * matching the specified date range (startDate to endDate in DD-MM-YYYY format).
     *
     * Safeguards:
     * - Date range cannot exceed 7 days to preserve server memory.
     * - End date cannot be before start date.
     * - End date cannot be in the future.
     * - Streams directly from R2 to client socket via StreamingResponseBody without local disk buffering.
     * - Transactional audit entry saved in log_backup_audits (action_type: 'Download', status: 'In Progress' -> 'Completed'/'Failed').
     *
     * @param startDateStr Start date in DD-MM-YYYY format (e.g. 24-10-2026)
     * @param endDateStr   End date in DD-MM-YYYY format (e.g. 31-10-2026)
     * @param request      HTTP request with pre-cached user claims
     * @param principal    Security principal
     * @return Streamed ZIP file response or validation error payload
     */
    @GetMapping("/download")
    @RateLimited(action = RateLimitAction.PUBLIC)
    public ResponseEntity<StreamingResponseBody> downloadLogs(
            @RequestParam("startDate") String startDateStr,
            @RequestParam("endDate") String endDateStr,
            HttpServletRequest request,
            Principal principal) {

        Object userIdObj = request.getAttribute("userId");
        Long userId = null;
        if (userIdObj instanceof Long) {
            userId = (Long) userIdObj;
        } else if (userIdObj instanceof String) {
            try {
                userId = Long.parseLong((String) userIdObj);
            } catch (NumberFormatException ignored) {
            }
        }
        String username = (principal != null && principal.getName() != null) ? principal.getName() : "authenticated-user";

        LocalDate startDate;
        LocalDate endDate;
        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("dd-MM-yyyy");

        try {
            startDate = LocalDate.parse(startDateStr.trim(), formatter);
            endDate = LocalDate.parse(endDateStr.trim(), formatter);
        } catch (Exception ex) {
            throw new IllegalArgumentException("Invalid date format. Expected format is DD-MM-YYYY (e.g. 24-10-2026).");
        }

        if (endDate.isBefore(startDate)) {
            throw new IllegalArgumentException("endDate cannot be before startDate (startDate: " + startDateStr + ", endDate: " + endDateStr + ").");
        }

        long daysBetween = ChronoUnit.DAYS.between(startDate, endDate);
        if (daysBetween > 7) {
            throw new IllegalArgumentException("Date range exceeds maximum limit of 7 days (requested: " + daysBetween + " days).");
        }

        LocalDate today = LocalDate.now(logBackupService.getZoneId());
        if (endDate.isAfter(today)) {
            throw new IllegalArgumentException("endDate cannot be in the future (today is " + today.format(formatter) + ").");
        }

        if (!logBackupService.isR2Enabled()) {
            throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "Cloudflare R2 storage is not configured or disabled.");
        }

        List<String> matchedKeys = logBackupService.findLogKeysForRange(startDate, endDate);
        if (matchedKeys == null || matchedKeys.isEmpty()) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, String.format("No log backups found in Cloudflare R2 for date range %s to %s.", startDateStr, endDateStr));
        }

        String zipFilename = String.format("speakit-logs-%s-to-%s.zip", startDateStr, endDateStr);
        Long auditId = logBackupService.recordDownloadAuditStart(username, userId);

        StreamingResponseBody responseBody;
        try {
            responseBody = logBackupService.createZipStream(matchedKeys, zipFilename, username, auditId);
        } catch (Exception ex) {
            if (auditId != null) {
                logBackupService.recordDownloadAuditFailure(auditId, "Failed to initialize zip stream: " + ex.getMessage());
            }
            throw ex;
        }

        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType("application/zip"))
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"" + zipFilename + "\"")
                .body(responseBody);
    }
}
