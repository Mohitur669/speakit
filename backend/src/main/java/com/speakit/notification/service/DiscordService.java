package com.speakit.notification.service;

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

    @Value("${app.discord.contact-form-webhook-url}")
    private String webhookUrl;

    private RestClient restClient;

    @PostConstruct
    public void init() {
        if (webhookUrl == null || webhookUrl.isBlank()) {
            log.warn("DISCORD_CONTACT_FORM_WEBHOOK_URL is missing or blank. Discord notifications disabled.");
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
        if (webhookUrl == null || webhookUrl.isBlank() || restClient == null) {
            return;
        }

        Map<String, Object> embed = buildEmbedPayload(name, email, subject, message, requestId);
        Map<String, Object> payload = Map.of("embeds", List.of(embed));

        executeWithRetry(() -> {
            restClient.post()
                    .uri(webhookUrl)
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(payload)
                    .retrieve()
                    .toBodilessEntity();
        });
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
