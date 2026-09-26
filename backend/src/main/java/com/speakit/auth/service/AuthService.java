package com.speakit.auth.service;
import com.speakit.tts.service.WSTicketService;
import com.speakit.notification.service.EmailService;
import com.speakit.notification.service.OtpEmailSender;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.auth.dto.VerifyEmailChangeRequest;
import com.speakit.auth.dto.VerifyEmailRequest;
import com.speakit.auth.dto.ResetPasswordRequest;
import com.speakit.auth.dto.ResendOtpRequest;
import com.speakit.auth.dto.ForgotPasswordRequest;
import com.speakit.auth.dto.AuthResponse;
import com.speakit.auth.dto.AuthRequest;
import com.speakit.user.dto.UserProfileUpdateRequest;
import com.speakit.user.dto.UpdateFullNameRequest;
import com.speakit.user.dto.UpdateUsernameRequest;
import com.speakit.user.dto.UpdateEmailRequest;

import com.speakit.config.WebSocketConfig;
import com.speakit.tts.dto.*;
import com.speakit.billing.entity.PlanType;
import com.speakit.user.entity.User;
import com.speakit.auth.entity.OtpVerification;
import com.speakit.user.repository.UserRepository;
import com.speakit.auth.repository.OtpVerificationRepository;
import com.speakit.security.JwtService;
import com.speakit.shared.util.Sanitizer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.billing.service.SubscriptionService;
import java.time.temporal.ChronoUnit;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final OtpVerificationRepository otpVerificationRepository;
    private final OtpEmailSender otpEmailSender;
    private final WSTicketService wsTicketService;
    private final WebSocketConfig webSocketConfig;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final SubscriptionService subscriptionService;

    @Value("${auth.session-duration-ms:7200000}")
    private long sessionDurationMs;

    @Value("${auth.idle-timeout-ms:60000}")
    private long idleTimeoutMs;

    @Value("${app.otp.expiry-minutes:10}")
    private int otpExpiryMinutes;

    @Transactional
    public AuthResponse register(AuthRequest request) {
        String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase();
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase();
        String sanitizedPhone = Sanitizer.sanitize(request.getPhoneNumber());
        String sanitizedFullName = (request.getFullName() != null && !request.getFullName().isBlank())
                ? Sanitizer.sanitize(request.getFullName()).trim()
                : null;

        if (userRepository.findByUsername(sanitizedUsername).isPresent()) {
            throw new RuntimeException("Username already taken");
        }
        if (userRepository.findByEmail(sanitizedEmail).isPresent()) {
            throw new RuntimeException("Email already taken");
        }
        if (userRepository.findByPhoneNumber(sanitizedPhone).isPresent()) {
            throw new RuntimeException("Phone number already taken");
        }

        var user = User.builder()
                .username(sanitizedUsername)
                .fullName(sanitizedFullName)
                .email(sanitizedEmail)
                .phoneNumber(sanitizedPhone)
                .password(passwordEncoder.encode(request.getPassword()))
                .role("ROLE_USER")
                .planType(PlanType.FREE)
                .emailVerified(false)
                .accountStatus("PENDING_VERIFICATION")
                .consentAccepted(true)
                .consentTimestamp(LocalDateTime.now())
                .build();
        user = userRepository.save(user);

        log.info("New user registered in pending verification status: {}", sanitizedUsername);

        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);
        
        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .email(sanitizedEmail)
                .otpHash(otpHash)
                .purpose("SIGNUP_VERIFICATION")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .attemptsRemaining(5)
                .consumed(false)
                .build();
        otpVerificationRepository.save(verification);

        otpEmailSender.sendOtpEmail(sanitizedEmail, sanitizedUsername, rawOtp, otpExpiryMinutes);

        return AuthResponse.builder()
                .username(user.getUsername())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(user.getRole())
                .planType(user.getPlanType().name())
                .sessionVersion(user.getSessionVersion())
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .emailVerified(user.isEmailVerified())
                .build();
    }

    public AuthResponse login(AuthRequest request) {
        String sanitizedIdentifier = Sanitizer.sanitize(request.getUsername()).toLowerCase();

        var user = userRepository.findByUsername(sanitizedIdentifier)
                .or(() -> userRepository.findByEmail(sanitizedIdentifier))
                .or(() -> userRepository.findByPhoneNumber(sanitizedIdentifier))
                .or(() -> {
                    if (sanitizedIdentifier.matches("\\d{7,15}")) {
                        return userRepository.findByPhoneNumberSuffix(sanitizedIdentifier);
                    }
                    return Optional.empty();
                })
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!user.isActive()) {
            throw new RuntimeException("Account is deactivated. Please contact support.");
        }

        if (!"ACTIVE".equals(user.getAccountStatus()) || !user.isEmailVerified()) {
            throw new RuntimeException("EMAIL_NOT_VERIFIED:" + user.getEmail());
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        user.getUsername(),
                        request.getPassword()
                )
        );

        userRepository.save(user);
        
        log.info("User {} logged in successfully", user.getUsername());
        return authenticate(user, user.getSessionVersion());
    }

    public void logout(String username) {
        userRepository.incrementSessionVersion(username);
        webSocketConfig.notifyLogout(username);
        log.info("User {} logged out, session invalidated", username);
    }

    public String issueWSTicket(String username) {
        return wsTicketService.createTicket(username);
    }

    public boolean isUsernameTaken(String username) {
        return userRepository.findByUsername(Sanitizer.sanitize(username).toLowerCase()).isPresent();
    }

    public boolean isEmailTaken(String email) {
        return userRepository.findByEmail(Sanitizer.sanitize(email).toLowerCase()).isPresent();
    }

    public boolean isPhoneTaken(String phone) {
        return userRepository.findByPhoneNumber(Sanitizer.sanitize(phone)).isPresent();
    }

    public AuthResponse getUserProfile(String username) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public void requestProfileUpdate(String currentUsername, String currentPassword) {
        var user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        if (currentPassword != null && !currentPassword.isBlank()) {
            if (!passwordEncoder.matches(currentPassword, user.getPassword())) {
                throw new RuntimeException("Incorrect current password");
            }
        }

        String email = user.getEmail().toLowerCase().trim();
        otpVerificationRepository.invalidateExistingOtps(email, "PROFILE_UPDATE");
        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);

        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .email(email)
                .otpHash(otpHash)
                .purpose("PROFILE_UPDATE")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .attemptsRemaining(5)
                .consumed(false)
                .build();
        otpVerificationRepository.save(verification);

        otpEmailSender.sendOtpEmail(email, user.getUsername(), rawOtp, otpExpiryMinutes);
        log.info("Profile update OTP generated and sent to current email: {}", maskEmail(email));
    }

    @Transactional
    public void requestProfileUpdate(String currentUsername) {
        requestProfileUpdate(currentUsername, null);
    }

    @Transactional
    public AuthResponse updateProfile(String currentUsername, UserProfileUpdateRequest request) {
        var user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (request.getCurrentPassword() == null || !passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        if (request.getOtp() == null || request.getOtp().isBlank()) {
            throw new RuntimeException("OTP is required to update profile");
        }

        final String currentEmail = user.getEmail();
        var verification = otpVerificationRepository.findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(currentEmail, "PROFILE_UPDATE")
                .or(() -> otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(currentEmail, "PROFILE_UPDATE"))
                .orElseThrow(() -> new RuntimeException("No active profile update request found."));

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("OTP has expired.");
        }

        if (verification.getAttemptsRemaining() <= 0) {
            throw new RuntimeException("Maximum OTP attempts exceeded.");
        }

        String providedHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(providedHash)) {
            verification.setAttemptsRemaining(verification.getAttemptsRemaining() - 1);
            otpVerificationRepository.save(verification);
            throw new RuntimeException("Invalid OTP.");
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        boolean hasChanges = false;

        if (request.getFullName() != null) {
            String sanitizedFullName = Sanitizer.sanitize(request.getFullName()).trim();
            user.setFullName(sanitizedFullName);
            hasChanges = true;
        }

        if (request.getUsername() != null && !request.getUsername().equalsIgnoreCase(user.getUsername())) {
            String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase();
            if (userRepository.findByUsername(sanitizedUsername).isPresent()) {
                throw new RuntimeException("Username already taken");
            }
            user.setUsername(sanitizedUsername);
            hasChanges = true;
        }

        if (request.getPhoneNumber() != null && !request.getPhoneNumber().equals(user.getPhoneNumber())) {
            String sanitizedPhone = Sanitizer.sanitize(request.getPhoneNumber());
            if (userRepository.findByPhoneNumber(sanitizedPhone).isPresent()) {
                throw new RuntimeException("Phone number already taken");
            }
            user.setPhoneNumber(sanitizedPhone);
            hasChanges = true;
        }

        if (request.getEmail() != null && !request.getEmail().equalsIgnoreCase(user.getEmail())) {
            String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase();
            if (userRepository.findByEmail(sanitizedEmail).isPresent()) {
                throw new RuntimeException("Email already taken");
            }
            user.setEmail(sanitizedEmail);
            user.setEmailVerified(true); 
            hasChanges = true;
        }

        if (hasChanges) {
            user = userRepository.save(user);
        }

        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public AuthResponse updateFullName(String username, UpdateFullNameRequest request) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (request.getFullName() == null || request.getFullName().isBlank()) {
            throw new RuntimeException("Full name is required");
        }

        String sanitizedFullName = Sanitizer.sanitize(request.getFullName()).trim();
        user.setFullName(sanitizedFullName);
        user = userRepository.save(user);
        log.info("Full name updated for user: {}", user.getUsername());
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public AuthResponse updateUsername(String currentUsername, UpdateUsernameRequest request) {
        var user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (request.getUsername() == null || request.getUsername().isBlank()) {
            throw new RuntimeException("Username is required");
        }

        String newUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase().trim();
        if (!newUsername.equalsIgnoreCase(user.getUsername())) {
            if (userRepository.findByUsername(newUsername).isPresent()) {
                throw new RuntimeException("Username already taken");
            }
            user.setUsername(newUsername);
            user = userRepository.save(user);
            log.info("Username updated from {} to {}", currentUsername, newUsername);
        }

        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public void requestEmailChangeOtp(String username, String currentPassword) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (currentPassword == null || !passwordEncoder.matches(currentPassword, user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        String email = user.getEmail().toLowerCase().trim();
        otpVerificationRepository.invalidateExistingOtps(email, "EMAIL_CHANGE");

        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);
        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .email(email)
                .otpHash(otpHash)
                .purpose("EMAIL_CHANGE")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .attemptsRemaining(5)
                .consumed(false)
                .build();
        otpVerificationRepository.save(verification);

        otpEmailSender.sendOtpEmail(email, user.getUsername(), rawOtp, otpExpiryMinutes);
        log.info("Email change OTP generated for user: {}", user.getUsername());
    }

    @Transactional
    public AuthResponse updateEmail(String username, UpdateEmailRequest request) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (request.getCurrentPassword() == null || !passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        if (request.getOtp() == null || request.getOtp().isBlank()) {
            throw new RuntimeException("OTP is required to update email");
        }

        String currentEmail = user.getEmail().toLowerCase().trim();
        OtpVerification verification = otpVerificationRepository
                .findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(currentEmail, "EMAIL_CHANGE")
                .or(() -> otpVerificationRepository.findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(currentEmail, "PROFILE_UPDATE"))
                .or(() -> otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(currentEmail, "EMAIL_CHANGE"))
                .orElseThrow(() -> new RuntimeException("No active email update verification code found. Please request a new code."));

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Verification code has expired. Please request a new one.");
        }

        if (verification.getAttemptsRemaining() <= 0) {
            throw new RuntimeException("Maximum attempts exceeded. Please request a new code.");
        }

        String providedHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(providedHash)) {
            verification.setAttemptsRemaining(verification.getAttemptsRemaining() - 1);
            otpVerificationRepository.save(verification);
            throw new RuntimeException("Invalid verification code. Attempts remaining: " + verification.getAttemptsRemaining());
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        String newEmail = Sanitizer.sanitize(request.getNewEmail()).toLowerCase().trim();
        if (!newEmail.equalsIgnoreCase(user.getEmail())) {
            if (userRepository.findByEmail(newEmail).isPresent()) {
                throw new RuntimeException("Email already taken");
            }
            user.setEmail(newEmail);
            user.setEmailVerified(true);
            user = userRepository.save(user);
            log.info("Email updated for user {}: {}", user.getUsername(), maskEmail(newEmail));
        }

        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public AuthResponse verifyEmail(VerifyEmailRequest request) {
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        
        OtpVerification verification = otpVerificationRepository
                .findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(sanitizedEmail, "SIGNUP_VERIFICATION")
                .or(() -> otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(sanitizedEmail, "SIGNUP_VERIFICATION"))
                .orElseThrow(() -> {
                    log.warn("No active signup verification OTP found for email: {}", maskEmail(sanitizedEmail));
                    return new RuntimeException("Invalid or expired verification code.");
                });

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Verification code has expired. Please request a new one.");
        }

        if (verification.getAttemptsRemaining() <= 0) {
            throw new RuntimeException("Maximum attempts exceeded. Please request a new code.");
        }

        String providedHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(providedHash)) {
            verification.setAttemptsRemaining(verification.getAttemptsRemaining() - 1);
            otpVerificationRepository.save(verification);
            throw new RuntimeException("Invalid verification code. Attempts remaining: " + verification.getAttemptsRemaining());
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        User user = verification.getUser();
        user.setEmailVerified(true);
        user.setAccountStatus("ACTIVE");
        user = userRepository.save(user);

        log.info("User {} successfully verified email.", user.getUsername());
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public AuthResponse verifyEmailChange(String username, VerifyEmailChangeRequest request) {
        // We no longer use this since updateProfile immediately verifies email.
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public void resendOtp(ResendOtpRequest request) {
        String email = Sanitizer.sanitize(request.getEmail()).toLowerCase();
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (user.isEmailVerified()) {
            throw new RuntimeException("Email is already verified");
        }

        otpVerificationRepository.invalidateExistingOtps(email, "SIGNUP_VERIFICATION");

        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);
        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .email(email)
                .otpHash(otpHash)
                .purpose("SIGNUP_VERIFICATION")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .attemptsRemaining(5)
                .consumed(false)
                .build();
        otpVerificationRepository.save(verification);

        otpEmailSender.sendOtpEmail(email, user.getUsername(), rawOtp, otpExpiryMinutes);
        log.info("Signup OTP resent to email: {}", maskEmail(email));
    }

    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        String email = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        Optional<User> userOpt = userRepository.findByEmail(email);
        
        if (userOpt.isEmpty()) {
            log.info("Password reset requested for unknown email: {}", maskEmail(email));
            return;
        }

        User user = userOpt.get();
        otpVerificationRepository.invalidateExistingOtps(email, "PASSWORD_RESET");

        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);
        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .email(email)
                .otpHash(otpHash)
                .purpose("PASSWORD_RESET")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .attemptsRemaining(5)
                .consumed(false)
                .build();
        otpVerificationRepository.save(verification);

        otpEmailSender.sendOtpEmail(email, user.getUsername(), rawOtp, otpExpiryMinutes);
        log.info("Password reset OTP generated for user: {}", user.getUsername());
    }

    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        String email = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        OtpVerification verification = otpVerificationRepository
                .findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(email, "PASSWORD_RESET")
                .or(() -> otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(email, "PASSWORD_RESET"))
                .orElseThrow(() -> new RuntimeException("Invalid or expired password reset request."));

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            throw new RuntimeException("Reset code has expired. Please request a new one.");
        }

        if (verification.getAttemptsRemaining() <= 0) {
            throw new RuntimeException("Maximum attempts exceeded. Please request a new code.");
        }

        String providedHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(providedHash)) {
            verification.setAttemptsRemaining(verification.getAttemptsRemaining() - 1);
            otpVerificationRepository.save(verification);
            throw new RuntimeException("Invalid reset code. Attempts remaining: " + verification.getAttemptsRemaining());
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        User user = verification.getUser();
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        
        userRepository.incrementSessionVersion(user.getUsername());
        user.setSessionVersion(user.getSessionVersion() + 1);
        webSocketConfig.notifyLogout(user.getUsername());
        
        userRepository.save(user);
        log.info("Password successfully reset for user: {}", user.getUsername());
    }

    @Transactional
    public AuthResponse cancelProfileChanges(String username) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        otpVerificationRepository.invalidateExistingOtps(user.getEmail(), "PROFILE_UPDATE");
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public void resendProfileOtp(String username) {
        requestProfileUpdate(username);
    }

    @Transactional
    public void requestPasswordChangeOtp(String username, String currentPassword) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (currentPassword == null || !passwordEncoder.matches(currentPassword, user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        String email = user.getEmail().toLowerCase().trim();
        otpVerificationRepository.invalidateExistingOtps(email, "PASSWORD_CHANGE");

        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);
        OtpVerification verification = OtpVerification.builder()
                .user(user)
                .email(email)
                .otpHash(otpHash)
                .purpose("PASSWORD_CHANGE")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .attemptsRemaining(5)
                .consumed(false)
                .build();
        otpVerificationRepository.save(verification);

        otpEmailSender.sendOtpEmail(email, user.getUsername(), rawOtp, otpExpiryMinutes);
        log.info("Password change OTP generated for user: {}", user.getUsername());
    }

    @Transactional
    public void changePassword(String username, com.speakit.auth.dto.ChangePasswordRequest request) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (request.getCurrentPassword() == null || !passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        if (request.getNewPassword() == null || request.getNewPassword().isBlank()) {
            throw new RuntimeException("New password is required");
        }

        if (request.getOtp() != null && !request.getOtp().isBlank()) {
            String email = user.getEmail().toLowerCase().trim();
            OtpVerification verification = otpVerificationRepository
                    .findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(email, "PASSWORD_CHANGE")
                    .orElseThrow(() -> new RuntimeException("No active password change verification code found. Please request a new code."));

            if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
                throw new RuntimeException("Verification code has expired. Please request a new one.");
            }

            if (verification.getAttemptsRemaining() <= 0) {
                throw new RuntimeException("Maximum attempts exceeded. Please request a new code.");
            }

            String providedHash = hashOtp(request.getOtp());
            if (!verification.getOtpHash().equals(providedHash)) {
                verification.setAttemptsRemaining(verification.getAttemptsRemaining() - 1);
                otpVerificationRepository.save(verification);
                throw new RuntimeException("Invalid verification code. Attempts remaining: " + verification.getAttemptsRemaining());
            }

            verification.setConsumed(true);
            otpVerificationRepository.save(verification);
        }

        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        userRepository.incrementSessionVersion(user.getUsername());
        user.setSessionVersion(user.getSessionVersion() + 1);
        webSocketConfig.notifyLogout(user.getUsername());
        userRepository.save(user);
        log.info("Password successfully changed for user: {}", user.getUsername());
    }

    private String generateSecureOtp() {
        java.security.SecureRandom random = new java.security.SecureRandom();
        int otp = 100000 + random.nextInt(900000);
        return String.valueOf(otp);
    }

    private String hashOtp(String otp) {
        if (otp == null) {
            return "";
        }
        String cleanOtp = otp.trim().replaceAll("[^0-9]", "");
        try {
            java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(cleanOtp.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return java.util.Base64.getEncoder().encodeToString(hash);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new RuntimeException("Failed to hash OTP", e);
        }
    }

    private String maskEmail(String email) {
        if (email == null || !email.contains("@")) {
            return "***";
        }
        String[] parts = email.split("@");
        String local = parts[0];
        String domain = parts[1];
        if (local.length() <= 2) {
            return "***@" + domain;
        }
        return local.substring(0, 2) + "****" + domain;
    }

    private AuthResponse authenticate(User user, Long sessionVersion) {
        String role = user.getRole();
        String roleName = role.startsWith("ROLE_") ? role.substring(5) : role;
        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password(user.getPassword() != null ? user.getPassword() : "")
                .roles(roleName)
                .build();

        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", sessionVersion);
        String token = jwtService.generateToken(claims, userDetails);

        Integer dailyCount = null;
        Integer dailyLimit = null;
        Integer charactersUsed = null;
        Integer characterLimit = null;

        if (user.getId() != null && ttsHistoryRepository != null && subscriptionService != null) {
            try {
                LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
                dailyCount = (int) ttsHistoryRepository.countRecentByUserId(user.getId(), todayStart);
                dailyLimit = subscriptionService.getDailySynthesisLimit(user.getPlanType(), user.getSubscriptionStatus(), user.getPlanExpiry());

                LocalDateTime monthStart = LocalDateTime.now().withDayOfMonth(1).truncatedTo(ChronoUnit.DAYS);
                charactersUsed = (int) ttsHistoryRepository.sumCharactersUsedSince(user.getId(), monthStart);
                characterLimit = subscriptionService.getMonthlyCharacterLimit(user.getPlanType());
            } catch (Exception e) {
                log.warn("Failed to compute user usage stats for auth response", e);
            }
        }

        return AuthResponse.builder()
                .token(token)
                .username(user.getUsername())
                .fullName(user.getFullName())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(user.getRole())
                .planType(user.getPlanType().name())
                .sessionVersion(sessionVersion)
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .emailVerified(user.isEmailVerified())
                .characterLimit(characterLimit)
                .charactersUsed(charactersUsed)
                .dailyCount(dailyCount)
                .dailyLimit(dailyLimit)
                .build();
    }
}
