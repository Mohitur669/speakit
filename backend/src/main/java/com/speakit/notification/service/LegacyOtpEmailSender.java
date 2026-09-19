package com.speakit.notification.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Service;

/**
 * Adapter to allow quick rollback to the legacy SES/SMTP OTP email delivery.
 */
@Service
@ConditionalOnProperty(name = "app.otp.provider", havingValue = "legacy", matchIfMissing = false)
@RequiredArgsConstructor
@Slf4j
public class LegacyOtpEmailSender implements OtpEmailSender {

    private final EmailService emailService;

    @Override
    public void sendOtpEmail(String to, String username, String otpCode, int expiryMinutes) {
        log.debug("Routing OTP email through Legacy (EmailService)");
        emailService.sendOtpEmail(to, username, otpCode, expiryMinutes);
    }
}
