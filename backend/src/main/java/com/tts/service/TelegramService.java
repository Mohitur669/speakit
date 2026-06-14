package com.tts.service;

import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.http.client.JdkClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

import java.time.Duration;
import java.util.Map;

/**
 * High-Security Telegram Notification Service.
 * 
 * Implements:
 * - MarkdownV2 escaping to prevent message injection.
 * - Exponential backoff retry logic.
 * - Strict 5s timeouts.
 * - Secret protection (Backend-only).
 */
@Service
@Slf4j
public class TelegramService {

    @Value("${app.telegram.bot-token:}")
    private String botToken;

    @Value("${app.telegram.chat-id:}")
    private String chatId;

    private RestClient restClient;

    @PostConstruct
    public void validateSecrets() {
        if (botToken == null || botToken.isEmpty() || chatId == null || chatId.isEmpty()) {
            log.warn("TELEGRAM_BOT_TOKEN or TELEGRAM_CHAT_ID missing. Telegram notifications disabled.");
            return;
        }
        
        JdkClientHttpRequestFactory requestFactory = new JdkClientHttpRequestFactory();
        requestFactory.setReadTimeout(Duration.ofSeconds(5));
        
        this.restClient = RestClient.builder()
                .baseUrl("https://api.telegram.org/bot" + botToken)
                .requestFactory(requestFactory)
                .build();
    }

    public void sendNotification(String name, String email, String subject, String message, String requestId) {
        if (botToken == null || botToken.isEmpty() || chatId == null || chatId.isEmpty() || restClient == null) return;

        String formattedMessage = String.format(
            "*New Contact Form Submission*\n\n" +
            "*Name:* %s\n" +
            "*Email:* %s\n" +
            "*Subject:* %s\n" +
            "\n*Message:*\n%s\n\n" +
            "*Request ID:* `%s`",
            escapeMarkdown(name),
            escapeMarkdown(email),
            escapeMarkdown(subject),
            escapeMarkdown(message),
            escapeMarkdown(requestId)
        );

        executeWithRetry(() -> {
            restClient.post()
                    .uri("/sendMessage")
                    .contentType(MediaType.APPLICATION_JSON)
                    .body(Map.of(
                            "chat_id", chatId,
                            "text", formattedMessage,
                            "parse_mode", "MarkdownV2"
                    ))
                    .retrieve()
                    .toBodilessEntity();
        });
    }

    /**
     * Escapes characters for Telegram MarkdownV2 to prevent injection.
     */
    private String escapeMarkdown(String text) {
        if (text == null) return "";
        return text.replace("_", "\\_")
                .replace("*", "\\*")
                .replace("[", "\\[")
                .replace("]", "\\]")
                .replace("(", "\\(")
                .replace(")", "\\)")
                .replace("~", "\\~")
                .replace("`", "\\`")
                .replace(">", "\\>")
                .replace("#", "\\#")
                .replace("+", "\\+")
                .replace("-", "\\-")
                .replace("=", "\\=")
                .replace("|", "\\|")
                .replace("{", "\\{")
                .replace("}", "\\}")
                .replace(".", "\\.")
                .replace("!", "\\!");
    }

    private void executeWithRetry(Runnable action) {
        int maxRetries = 3;
        long backoffMs = 1000;

        for (int i = 0; i < maxRetries; i++) {
            try {
                action.run();
                return;
            } catch (Exception e) {
                log.warn("Telegram notification attempt {} failed: {}", i + 1, e.getMessage());
                if (i == maxRetries - 1) {
                    log.error("Telegram notification failed after all retries.");
                    break;
                }
                try {
                    Thread.sleep(backoffMs);
                    backoffMs *= 2; // Exponential backoff
                } catch (InterruptedException ie) {
                    Thread.currentThread().interrupt();
                }
            }
        }
    }
}
