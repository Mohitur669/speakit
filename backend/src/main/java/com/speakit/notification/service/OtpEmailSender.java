package com.speakit.notification.service;

public interface OtpEmailSender {
    void sendOtpEmail(String to, String username, String otpCode, int expiryMinutes);
}
