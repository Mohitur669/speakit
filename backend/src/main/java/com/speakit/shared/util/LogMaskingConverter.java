package com.speakit.shared.util;

import ch.qos.logback.classic.pattern.MessageConverter;
import ch.qos.logback.classic.spi.ILoggingEvent;
import java.util.regex.Pattern;

/**
 * Custom Logback Converter to intercept and redact sensitive fields
 * (passwords, OTPs, JWT tokens, authorizations, emails) from all log statements
 * before they are written to files or stdout.
 */
public class LogMaskingConverter extends MessageConverter {

    private static final Pattern EMAIL_PATTERN = Pattern.compile(
            "[a-zA-Z0-9_+&*-]+(?:\\.[a-zA-Z0-9_+&*-]+)*@(?:[a-zA-Z0-9-]+\\.)+[a-zA-Z]{2,7}"
    );

    private static final Pattern SENSITIVE_KEY_PATTERN = Pattern.compile(
            "(?i)\"(password|otp|token|jwt|secret|key|authorization|credential)\"\\s*:\\s*\"[^\"]+\""
    );

    private static final Pattern QUERY_PARAM_PATTERN = Pattern.compile(
            "(?i)(password|otp|token|jwt|secret|key|authorization|credential)=[^&\\s]+"
    );

    @Override
    public String convert(ILoggingEvent event) {
        String originalMessage = event.getFormattedMessage();
        if (originalMessage == null || originalMessage.isBlank()) {
            return originalMessage;
        }

        // Mask emails
        String masked = EMAIL_PATTERN.matcher(originalMessage).replaceAll("[EMAIL_REDACTED]");

        // Mask JSON keys
        masked = SENSITIVE_KEY_PATTERN.matcher(masked).replaceAll("\"$1\":\"[REDACTED]\"");

        // Mask query params
        masked = QUERY_PARAM_PATTERN.matcher(masked).replaceAll("$1=[REDACTED]");

        return masked;
    }
}
