package com.speakit.notification.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * Sends OTP emails using the Resend API via plain HttpClient.
 */
@Service
@ConditionalOnProperty(name = "app.otp.provider", havingValue = "resend", matchIfMissing = true)
@Slf4j
public class ResendOtpEmailSender implements OtpEmailSender {

    private final HttpClient httpClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    @Value("${resend.api-key:}")
    private String apiKey;

    @Value("${resend.from-address:noreply@speakit.com}")
    private String fromEmail;

    public ResendOtpEmailSender(HttpClient httpClient) {
        this.httpClient = httpClient;
    }

    public ResendOtpEmailSender() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    @Async
    @Override
    public void sendOtpEmail(String to, String username, String otpCode, int expiryMinutes) {
        String subject = "Your SpeakIT OTP Verification Code";
        String content = String.format(
                "<html>" +
                        "<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>"
                        +
                        "  <div style='background-color: #4F46E5; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;'>"
                        +
                        "    <h1 style='color: white; margin: 0; font-size: 24px;'>SpeakIT</h1>" +
                        "  </div>" +
                        "  <div style='border: 1px solid #e5e7eb; border-top: none; padding: 20px; border-radius: 0 0 8px 8px;'>"
                        +
                        "    <p>Hello <strong>%s</strong>,</p>" +
                        "    <p>You requested a verification code to access your SpeakIT account. Use the OTP code below to verify your identity:</p>"
                        +
                        "    <div style='text-align: center; margin: 30px 0;'>" +
                        "      <span style='background-color: #f3f4f6; border: 1px dashed #4F46E5; color: #4F46E5; font-size: 32px; font-weight: bold; letter-spacing: 5px; padding: 12px 30px; border-radius: 6px; display: inline-block;'>%s</span>"
                        +
                        "    </div>" +
                        "    <p style='color: #6b7280; font-size: 14px;'>This code is highly sensitive and will expire in <strong>%d minutes</strong>. If you did not initiate this request, please change your password immediately or contact security.</p>"
                        +
                        "    <hr style='border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;' />" +
                        "    <p style='font-size: 12px; color: #9ca3af;'>This is an automated security message. Please do not reply directly to this email.</p>"
                        +
                        "  </div>" +
                        "</body>" +
                        "</html>",
                username, otpCode, expiryMinutes);

        try {
            Map<String, Object> payload = new HashMap<>();
            payload.put("from", fromEmail);
            payload.put("to", List.of(to));
            payload.put("subject", subject);
            payload.put("html", content);
            
            String jsonPayload = objectMapper.writeValueAsString(payload);

            HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create("https://api.resend.com/emails"))
                    .timeout(Duration.ofSeconds(10))
                    .header("Authorization", "Bearer " + apiKey)
                    .header("Content-Type", "application/json")
                    .POST(HttpRequest.BodyPublishers.ofString(jsonPayload))
                    .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                log.info("Successfully sent OTP email via Resend API to: {} with subject: {}", maskEmail(to), subject);
            } else {
                log.error("Failed to send OTP email via Resend API to: {} with subject: {}. Status Code: {}, Response: {}",
                        maskEmail(to), subject, response.statusCode(), response.body());
            }
        } catch (Exception e) {
            log.error("Exception while sending OTP email via Resend API to: {} with subject: {}. Error: {}",
                    maskEmail(to), subject, e.getMessage(), e);
        }
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) return "";
        int index = email.indexOf("@");
        String local = email.substring(0, index);
        String domain = email.substring(index);
        if (local.length() <= 2) {
            return local.substring(0, 1) + "**" + domain;
        }
        return local.substring(0, 2) + "****" + domain;
    }
}
