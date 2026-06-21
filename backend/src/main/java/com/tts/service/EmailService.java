package com.tts.service;

import jakarta.annotation.PostConstruct;
import jakarta.mail.internet.MimeMessage;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.Body;
import software.amazon.awssdk.services.ses.model.Content;
import software.amazon.awssdk.services.ses.model.Destination;
import software.amazon.awssdk.services.ses.model.Message;
import software.amazon.awssdk.services.ses.model.SendEmailRequest;

import java.nio.charset.StandardCharsets;

/**
 * Enterprise Production-Grade Email Service for transactional email delivery.
 * Supports HTML templating, custom From/Reply-To headers, and asynchronous
 * execution.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class EmailService {

    private final JavaMailSender mailSender;

    @Value("${app.mail.from}")
    private String fromEmail;

    @Value("${app.mail.reply-to:support@mohitur.com}")
    private String replyToEmail;

    @Value("${app.email.provider:SMTP}")
    private String emailProvider;

    @Value("${aws.accessKeyId:}")
    private String awsAccessKey;

    @Value("${aws.secretKey:}")
    private String awsSecretKey;

    @Value("${aws.region:ap-south-1}")
    private String awsRegion;

    private SesClient sesClient;

    @PostConstruct
    public void init() {
        if ("SES_API".equalsIgnoreCase(emailProvider)) {
            if (awsAccessKey != null && !awsAccessKey.isBlank() && awsSecretKey != null && !awsSecretKey.isBlank()) {
                this.sesClient = SesClient.builder()
                        .region(Region.of(awsRegion))
                        .credentialsProvider(StaticCredentialsProvider.create(
                                AwsBasicCredentials.create(awsAccessKey, awsSecretKey)
                        ))
                        .build();
                log.info("Initialized AWS SES API Client for email delivery");
            } else {
                log.warn("AWS SES API selected but AWS credentials are empty. Email service will fallback to SMTP.");
            }
        }
    }

    /**
     * General purpose email sending method with TLS.
     */
    @Async
    public void sendEmail(String to, String subject, String htmlContent) {
        if ("SES_API".equalsIgnoreCase(emailProvider) && sesClient != null) {
            try {
                SendEmailRequest emailRequest = SendEmailRequest.builder()
                        .destination(Destination.builder().toAddresses(to).build())
                        .message(Message.builder()
                                .subject(Content.builder().data(subject).charset("UTF-8").build())
                                .body(Body.builder()
                                        .html(Content.builder().data(htmlContent).charset("UTF-8").build())
                                        .build())
                                .build())
                        .source(fromEmail)
                        .replyToAddresses(replyToEmail)
                        .build();

                sesClient.sendEmail(emailRequest);
                log.info("Successfully sent transactional email via AWS SES API to: {} with subject: {}", to, subject);
            } catch (Exception e) {
                log.error("Failed to send transactional email via AWS SES API to: {} with subject: {}. Error: {}", to, subject,
                        e.getMessage(), e);
            }
        } else {
            try {
                MimeMessage message = mailSender.createMimeMessage();
                MimeMessageHelper helper = new MimeMessageHelper(
                        message,
                        MimeMessageHelper.MULTIPART_MODE_MIXED_RELATED,
                        StandardCharsets.UTF_8.name());

                helper.setFrom(fromEmail);
                helper.setReplyTo(replyToEmail);
                helper.setTo(to);
                helper.setSubject(subject);
                helper.setText(htmlContent, true);

                mailSender.send(message);
                log.info("Successfully sent transactional email via SMTP to: {} with subject: {}", to, subject);
            } catch (Exception e) {
                log.error("Failed to send transactional email via SMTP to: {} with subject: {}. Error: {}", to, subject,
                        e.getMessage(), e);
            }
        }
    }

    /**
     * Sends One-Time Password (OTP) for authentication or critical operations.
     */
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
        sendEmail(to, subject, content);
    }

    /**
     * Sends Verification Link for account onboarding activation.
     */
    public void sendVerificationEmail(String to, String username, String verificationUrl) {
        String subject = "Verify your SpeakIT Account";
        String content = String.format(
                "<html>" +
                        "<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>"
                        +
                        "  <div style='background-color: #4F46E5; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;'>"
                        +
                        "    <h1 style='color: white; margin: 0; font-size: 24px;'>Welcome to SpeakIT</h1>" +
                        "  </div>" +
                        "  <div style='border: 1px solid #e5e7eb; border-top: none; padding: 20px; border-radius: 0 0 8px 8px;'>"
                        +
                        "    <p>Hello <strong>%s</strong>,</p>" +
                        "    <p>Thank you for signing up for SpeakIT! To activate your account and start generating high-quality speech, click the button below to verify your email address:</p>"
                        +
                        "    <div style='text-align: center; margin: 35px 0;'>" +
                        "      <a href='%s' style='background-color: #4F46E5; color: white; padding: 12px 30px; font-weight: bold; text-decoration: none; border-radius: 6px; display: inline-block;'>Verify Email Address</a>"
                        +
                        "    </div>" +
                        "    <p>Or copy and paste this URL into your browser:</p>" +
                        "    <p style='word-break: break-all; font-size: 14px; color: #4F46E5;'><a href='%s'>%s</a></p>"
                        +
                        "    <hr style='border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;' />" +
                        "    <p style='font-size: 12px; color: #9ca3af;'>If you didn't create a SpeakIT account, you can safely ignore this email.</p>"
                        +
                        "  </div>" +
                        "</body>" +
                        "</html>",
                username, verificationUrl, verificationUrl, verificationUrl);
        sendEmail(to, subject, content);
    }

    /**
     * Sends Password Reset link for account security restoration.
     */
    public void sendPasswordResetEmail(String to, String username, String resetUrl) {
        String subject = "Reset your SpeakIT Password";
        String content = String.format(
                "<html>" +
                        "<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>"
                        +
                        "  <div style='background-color: #ef4444; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;'>"
                        +
                        "    <h1 style='color: white; margin: 0; font-size: 24px;'>SpeakIT Password Reset</h1>" +
                        "  </div>" +
                        "  <div style='border: 1px solid #e5e7eb; border-top: none; padding: 20px; border-radius: 0 0 8px 8px;'>"
                        +
                        "    <p>Hello <strong>%s</strong>,</p>" +
                        "    <p>We received a request to reset the password for your SpeakIT account. Click the button below to set a new password:</p>"
                        +
                        "    <div style='text-align: center; margin: 35px 0;'>" +
                        "      <a href='%s' style='background-color: #ef4444; color: white; padding: 12px 30px; font-weight: bold; text-decoration: none; border-radius: 6px; display: inline-block;'>Reset Password</a>"
                        +
                        "    </div>" +
                        "    <p>Or copy and paste this URL into your browser:</p>" +
                        "    <p style='word-break: break-all; font-size: 14px; color: #ef4444;'><a href='%s'>%s</a></p>"
                        +
                        "    <p style='color: #6b7280; font-size: 14px;'>This link is valid for 24 hours. If you did not request a password reset, please ignore this email; your account is secure.</p>"
                        +
                        "    <hr style='border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;' />" +
                        "    <p style='font-size: 12px; color: #9ca3af;'>For security reasons, do not forward this email to anyone.</p>"
                        +
                        "  </div>" +
                        "</body>" +
                        "</html>",
                username, resetUrl, resetUrl, resetUrl);
        sendEmail(to, subject, content);
    }

    /**
     * Sends Welcome onboarding message.
     */
    public void sendWelcomeEmail(String to, String username) {
        String subject = "Welcome to SpeakIT!";
        String content = String.format(
                "<html>" +
                        "<body style='font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;'>"
                        +
                        "  <div style='background-color: #10B981; padding: 20px; text-align: center; border-radius: 8px 8px 0 0;'>"
                        +
                        "    <h1 style='color: white; margin: 0; font-size: 24px;'>Welcome to SpeakIT!</h1>" +
                        "  </div>" +
                        "  <div style='border: 1px solid #e5e7eb; border-top: none; padding: 20px; border-radius: 0 0 8px 8px;'>"
                        +
                        "    <p>Hello <strong>%s</strong>,</p>" +
                        "    <p>We're thrilled to have you here! SpeakIT is designed to give your documents, web pages, and written stories a real, human voice using cutting edge AI text-to-speech technology.</p>"
                        +
                        "    <p>Here are a few things you can do next:</p>" +
                        "    <ul>" +
                        "      <li>Explore our voice profiles and languages.</li>" +
                        "      <li>Upload text or document files to generate MP3 assets.</li>" +
                        "      <li>Configure integration keys in your user dashboard.</li>" +
                        "    </ul>" +
                        "    <p>If you have any questions, our support team is always ready to help at <a href='mailto:support@mohitur.com'>support@mohitur.com</a>.</p>"
                        +
                        "    <hr style='border: none; border-top: 1px solid #e5e7eb; margin: 20px 0;' />" +
                        "    <p style='font-size: 12px; color: #9ca3af;'>Happy listening!<br />The SpeakIT Team</p>" +
                        "  </div>" +
                        "</body>" +
                        "</html>",
                username);
        sendEmail(to, subject, content);
    }
}
