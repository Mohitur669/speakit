package com.speakit.config;

import io.sentry.SentryEvent;
import io.sentry.SentryOptions.BeforeSendCallback;
import io.sentry.Hint;
import io.sentry.protocol.Message;
import io.sentry.protocol.Request;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.util.Map;
import java.util.regex.Pattern;

/**
 * Enterprise security configuration for Sentry.
 * Enforces DPDP Act 2023 / IT Act 2000 data compliance by scrubbing PII
 * (emails, passwords, tokens, OTP codes, authorizations) before it is sent to Sentry.
 */
@Configuration
public class SentryConfig {

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "[a-zA-Z0-9_+&*-]+(?:\\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,7}"
    );

    private static final Pattern SENSITIVE_KEY_PATTERN = Pattern.compile(
            "(?i)(password|otp|token|jwt|secret|key|authorization|credential)"
    );

    @Bean
    public BeforeSendCallback sentryBeforeSendCallback() {
        return (event, hint) -> {
            // 1. Scrub Request headers and parameters
            Request request = event.getRequest();
            if (request != null) {
                // Scrub Header values matching sensitive keys
                Map<String, String> headers = request.getHeaders();
                if (headers != null) {
                    headers.entrySet().forEach(entry -> {
                        if (SENSITIVE_KEY_PATTERN.matcher(entry.getKey()).find()) {
                            entry.setValue("[REDACTED]");
                        }
                    });
                }

                // Scrub payload/request data containing sensitive values
                Object rawData = request.getData();
                if (rawData instanceof String) {
                    request.setData(scrubString((String) rawData));
                }
            }

            // 2. Scrub Exception and Logger Messages
            Message message = event.getMessage();
            if (message != null && message.getFormatted() != null) {
                message.setFormatted(scrubString(message.getFormatted()));
            }

            return event;
        };
    }

    /**
     * Replaces emails and structured sensitive parameters in a string payload.
     */
    private String scrubString(String input) {
        if (input == null || input.isBlank()) {
            return input;
        }

        // Redact standard emails
        String scrubbed = EMAIL_PATTERN.matcher(input).replaceAll("[EMAIL_REDACTED]");

        // Redact JSON fields matching sensitive parameters (e.g. "password":"value")
        scrubbed = scrubbed.replaceAll("(?i)\"(password|otp|token|jwt|secret|key|authorization|credential)\"\\s*:\\s*\"[^\"]+\"", "\"$1\":\"[REDACTED]\"");

        // Redact URI query parameters matching sensitive fields (e.g. password=value)
        scrubbed = scrubbed.replaceAll("(?i)(password|otp|token|jwt|secret|key|authorization|credential)=[^&\\s]+", "$1=[REDACTED]");

        return scrubbed;
    }
}
