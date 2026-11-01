package com.speakit.notification.service;

import com.speakit.notification.entity.LogBackupAudit;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * High-Security Discord Webhook Notification Service.
 *
 * Implements:
 * - Native Discord Rich Embeds with topic-based visual accents.
 * - String boundary guards (prevent Discord 400 Bad Request on oversized inputs).
 * - Exponential backoff retry logic.
 * - Strict 5s timeouts via JdkClientHttpRequestFactory.
 * - Asynchronous execution to isolate notification latency from client HTTP response.
 */
@Service
@Slf4j
public class DiscordService {

    @Value("${app.discord.contact-form-webhook-url:}")
    private String contactWebhookUrl;

    @Value("${app.discord.backend-webhook-url:}")
    private String backendWebhookUrl;

    @Value("${app.discord.infra-webhook-url:}")
    private String infraWebhookUrl;

    @Value("${cloudflare.r2.logs.environment:${LOG_ENVIRONMENT:local}}")
    private String logEnvironment;

    private RestClient restClient;

    @PostConstruct
    public void init() {
        boolean hasContact = contactWebhookUrl != null && !contactWebhookUrl.isBlank();
        boolean hasBackend = backendWebhookUrl != null && !backendWebhookUrl.isBlank();
        boolean hasInfra = infraWebhookUrl != null && !infraWebhookUrl.isBlank();

        if (!hasContact && !hasBackend && !hasInfra) {
            log.warn("Discord webhook URLs are missing or blank. Discord notifications disabled.");
            return;
        }

        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory();
        requestFactory.setReadTimeout(Duration.ofSeconds(5));

        this.restClient = RestClient.builder()
                .requestFactory(requestFactory)
                .build();
    }

    @Async
    public void sendNotification(String name, String email, String subject, String message, String requestId) {
        if (contactWebhookUrl == null || contactWebhookUrl.isBlank() || restClient == null) {
            return;
        }

        Map<String, Object> embed = buildEmbedPayload(name, email, subject, message, requestId);
        Map<String, Object> payload = Map.of("embeds", List.of(embed));

        executeWithRetry(() -> {
            restClient.post()
                    .uri(contactWebhookUrl)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .toBodilessEntity();
        });
    }

    /**
     * Dispatches an operational security alert when a user exercises account deletion (DPDP / Apple 5.1.1v).
     */
    @Async
    public void sendAccountDeletionAlert(String username, Long userId, String email, String reason) {
        if (backendWebhookUrl == null || backendWebhookUrl.isBlank() || restClient == null) {
            log.debug("Discord backend webhook URL not configured. Skipping account deletion alert.");
            return;
        }

        try {
            Map<String, Object> embed = Map.of(
                    "title", "🚨 User Account Deleted (DPDP / Apple Guideline 5.1.1v)",
                    "description", "A user has permanently deleted their account and purged all personal data.",
                    "color", 0xEF4444, // Red
                    "fields", List.of(
                            Map.of("name", "👤 Username", "value", username != null ? username : "N/A", "inline", true),
                            Map.of("name", "🆔 User ID", "value", String.valueOf(userId), "inline", true),
                            Map.of("name", "📧 Email", "value", email != null ? email : "N/A", "inline", true),
                            Map.of("name", "📝 Reason / Mode", "value", (reason != null && !reason.isBlank()) ? reason : "In-App Self Service", "inline", false),
                            Map.of("name", "🌐 Environment", "value", logEnvironment != null ? logEnvironment.toUpperCase() : "PROD", "inline", true)
                    ),
                    "timestamp", Instant.now().toString()
            );

            Map<String, Object> payload = Map.of(
                    "username", "SpeakIT Security Sentinel",
                    "embeds", List.of(embed)
            );

            restClient.post()
                    .uri(backendWebhookUrl)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .toBodilessEntity();

            log.info("Successfully dispatched Discord account deletion alert for user: {} (id: {})", username, userId);
        } catch (Exception ex) {
            log.warn("Failed to dispatch Discord account deletion alert: {}", ex.getMessage());
        }
    }

    public void sendLogBackupNotification(LogBackupAudit audit) {
        if (infraWebhookUrl == null || infraWebhookUrl.isBlank() || restClient == null || audit == null) {
            return;
        }

        Map<String, Object> embed = buildLogBackupEmbedPayload(audit);
        Map<String, Object> payload = Map.of("embeds", List.of(embed));

        executeWithRetry(() -> {
            restClient.post()
                    .uri(infraWebhookUrl)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .toBodilessEntity();
        });
    }

    private Map<String, Object> buildLogBackupEmbedPayload(LogBackupAudit audit) {
        String status = audit.getStatus() != null ? audit.getStatus() : "Unknown";
        String actionType = audit.getActionType() != null ? audit.getActionType() : "Upload";
        String triggerType = audit.getTriggerType() != null ? audit.getTriggerType() : "Manual";
        String triggeredBy = audit.getTriggeredBy() != null ? audit.getTriggeredBy() : "system";

        String title;
        int color;
        String description;

        if ("Completed".equalsIgnoreCase(status)) {
            if ("Download".equalsIgnoreCase(actionType)) {
                title = "📥 Cloudflare R2 Log Download — Streamed";
                color = 0x5865F2; // Discord Blurple
                description = "On-the-fly streaming ZIP archive piped to client socket without server disk buffering.";
            } else {
                if ("Scheduled".equalsIgnoreCase(triggerType)) {
                    title = "🗄️ Cloudflare R2 Log Backup — Completed";
                    description = "Scheduled midnight log backup to Cloudflare R2 completed successfully.";
                } else {
                    title = "🚀 Cloudflare R2 Log Snapshot — Completed";
                    description = "Manual active log snapshot to Cloudflare R2 completed successfully.";
                }
                color = 0x10B981; // Emerald Green
            }
        } else if ("Skipped".equalsIgnoreCase(status)) {
            title = "⚠️ Cloudflare R2 Log Backup — Skipped";
            color = 0xF59E0B; // Amber
            description = "Log backup operation was skipped.";
        } else {
            title = "❌ Cloudflare R2 Log " + actionType + " — Failed";
            color = 0xE02424; // Red
            description = "Log " + actionType.toLowerCase() + " operation encountered an error.";
        }

        List<Map<String, Object>> fields = new ArrayList<>();
        fields.add(Map.of("name", "📌 Action", "value", actionType, "inline", true));
        fields.add(Map.of("name", "⚡ Trigger", "value", triggerType, "inline", true));
        fields.add(Map.of("name", "👤 Triggered By", "value", truncate(triggeredBy, 100), "inline", true));

        String bucket = audit.getBucketName() != null && !audit.getBucketName().isBlank() ? audit.getBucketName() : "speakit-logs";
        fields.add(Map.of("name", "🪣 Bucket", "value", bucket, "inline", true));
        String duration = audit.getExecutionDurationMs() != null ? audit.getExecutionDurationMs() + " ms" : "N/A";
        fields.add(Map.of("name", "⏱️ Duration", "value", duration, "inline", true));
        fields.add(Map.of("name", "🆔 Audit ID", "value", "#" + (audit.getId() != null ? audit.getId() : "N/A"), "inline", true));

        if ("Completed".equalsIgnoreCase(status)) {
            if ("Download".equalsIgnoreCase(actionType)) {
                if (audit.getObjectKey() != null && !audit.getObjectKey().isBlank()) {
                    fields.add(Map.of("name", "📁 Archive File", "value", "`" + truncate(audit.getObjectKey(), 250) + "`", "inline", false));
                }
                StringBuilder sb = new StringBuilder();
                if (audit.getOriginalSizeBytes() != null && audit.getOriginalSizeBytes() > 0) {
                    sb.append("• **Total Streamed:** ").append(formatBytes(audit.getOriginalSizeBytes())).append("\n");
                }
                int chunks = audit.getArchivedChunksCount() != null ? audit.getArchivedChunksCount() : 0;
                sb.append("• **Files Streamed:** ").append(chunks).append(" log file(s)\n");
                sb.append("• **Buffer Strategy:** Zero-RAM memory pipe (`StreamingResponseBody`)\n");
                fields.add(Map.of("name", "📊 Stream Telemetry", "value", sb.toString(), "inline", false));
            } else {
                if (audit.getObjectKey() != null && !audit.getObjectKey().isBlank()) {
                    fields.add(Map.of("name", "📦 Active Log Key", "value", "`" + truncate(audit.getObjectKey(), 250) + "`", "inline", false));
                }
                StringBuilder sb = new StringBuilder();
                if (audit.getOriginalSizeBytes() != null && audit.getOriginalSizeBytes() > 0) {
                    sb.append("• **Original Size:** ").append(formatBytes(audit.getOriginalSizeBytes())).append("\n");
                }
                if (audit.getCompressedSizeBytes() != null && audit.getCompressedSizeBytes() > 0) {
                    sb.append("• **Compressed Size:** ").append(formatBytes(audit.getCompressedSizeBytes()));
                    if (audit.getCompressionRatio() != null && !audit.getCompressionRatio().isBlank()) {
                        sb.append(" (").append(audit.getCompressionRatio()).append(" saved)");
                    }
                    sb.append("\n");
                }
                int chunks = audit.getArchivedChunksCount() != null ? audit.getArchivedChunksCount() : 0;
                sb.append("• **Files Uploaded:** 1 active snapshot + ").append(chunks).append(" rolled chunk(s)\n");
                if (audit.getEtag() != null && !audit.getEtag().isBlank()) {
                    sb.append("• **ETag:** `").append(truncate(audit.getEtag(), 100)).append("`\n");
                }
                fields.add(Map.of("name", "📊 Telemetry & Compression", "value", sb.toString(), "inline", false));
            }
        } else if ("Skipped".equalsIgnoreCase(status)) {
            String reason = audit.getErrorMessage() != null && !audit.getErrorMessage().isBlank()
                    ? truncate(audit.getErrorMessage(), 1000)
                    : "No details provided.";
            fields.add(Map.of("name", "💬 Reason", "value", reason, "inline", false));
        } else if ("Failed".equalsIgnoreCase(status)) {
            String error = audit.getErrorMessage() != null && !audit.getErrorMessage().isBlank()
                    ? "`" + truncate(audit.getErrorMessage(), 1000) + "`"
                    : "Unknown failure reason.";
            fields.add(Map.of("name", "⚠️ Error Details", "value", error, "inline", false));
            if (audit.getObjectKey() != null && !audit.getObjectKey().isBlank()) {
                fields.add(Map.of("name", "📦 Target Key", "value", "`" + truncate(audit.getObjectKey(), 250) + "`", "inline", false));
            }
        }

        String envName = cleanEnv(logEnvironment);
        return Map.of(
                "title", title,
                "description", description,
                "color", color,
                "fields", fields,
                "timestamp", Instant.now().toString(),
                "footer", Map.of("text", "SpeakIT Backend Operations • Environment: " + envName)
        );
    }

    private String formatBytes(Long bytes) {
        if (bytes == null || bytes <= 0) return "0 B";
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return String.format("%.2f KB", bytes / 1024.0);
        return String.format("%.2f MB", bytes / (1024.0 * 1024.0));
    }

    private String cleanEnv(String val) {
        if (val == null) return "local";
        String trimmed = val.trim();
        if (trimmed.contains("#")) {
            trimmed = trimmed.split("#")[0].trim();
        }
        return trimmed.isEmpty() ? "local" : trimmed;
    }

    private Map<String, Object> buildEmbedPayload(String name, String email, String subject, String message, String requestId) {
        String safeName = truncate(name, 250);
        String safeEmail = truncate(email, 250);
        String safeSubject = truncate(subject, 250);
        String safeMessage = truncate(message, 4000);
        String safeRequestId = truncate(requestId, 100);

        List<Map<String, Object>> fields = List.of(
                Map.of("name", "👤 Sender Name", "value", safeName.isEmpty() ? "Anonymous" : safeName, "inline", true),
                Map.of("name", "✉️ Sender Email", "value", safeEmail.isEmpty() ? "N/A" : safeEmail, "inline", true),
                Map.of("name", "📌 Topic", "value", safeSubject.isEmpty() ? "General Inquiry" : safeSubject, "inline", true),
                Map.of("name", "💬 Message", "value", safeMessage.isEmpty() ? "*(No content)*" : safeMessage, "inline", false),
                Map.of("name", "🆔 Request ID", "value", "`" + safeRequestId + "`", "inline", false)
        );

        return Map.of(
                "title", "📬 New Contact Form Submission",
                "color", resolveColor(subject),
                "fields", fields,
                "timestamp", Instant.now().toString(),
                "footer", Map.of("text", "SpeakIT Administrative Alert System")
        );
    }

    private int resolveColor(String topic) {
        if (topic == null) return 0x5865F2; // Discord Blurple
        return switch (topic.toLowerCase()) {
            case "billing" -> 0xE02424; // Red
            case "technical support", "support" -> 0x3B82F6; // Blue
            case "enterprise sales", "enterprise" -> 0x10B981; // Emerald Green
            case "product feedback", "feedback" -> 0xF59E0B; // Amber
            default -> 0x5865F2; // Discord Blurple
        };
    }

    private String truncate(String text, int maxLength) {
        if (text == null) return "";
        if (text.length() <= maxLength) return text;
        return text.substring(0, Math.max(0, maxLength - 3)) + "...";
    }

    private void executeWithRetry(Runnable action) {
        int maxRetries = 3;
        long backoffMs = 1000;

        for (int i = 0; i < maxRetries; i++) {
            try {
                action.run();
                log.info("Discord contact notification dispatched successfully.");
                return;
            } catch (Exception e) {
                log.warn("Discord notification attempt {} failed: {}", i + 1, e.getMessage());
                if (i == maxRetries - 1) {
                    log.error("Discord notification failed after all retries.");
                    break;
                }
                try {
                    Thread.sleep(backoffMs);
                    backoffMs *= 2;
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                    break;
                }
            }
        }
    }
}
