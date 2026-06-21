package com.tts.service;

import com.tts.config.WebSocketConfig;
import com.tts.dto.*;
import com.tts.entity.PlanType;
import com.tts.entity.User;
import com.tts.entity.OtpVerification;
import com.tts.repository.UserRepository;
import com.tts.repository.OtpVerificationRepository;
import com.tts.security.JwtService;
import com.tts.util.Sanitizer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Handles core authentication flows including user registration, login, 
 * session management, and JWT token provisioning.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final WebSocketConfig webSocketConfig;
    private final WSTicketService wsTicketService;
    private final SystemParameterService systemParameterService;
    private final OtpVerificationRepository otpVerificationRepository;
    private final EmailService emailService;

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

        var user = User.builder()
                .username(sanitizedUsername)
                .email(sanitizedEmail)
                .phoneNumber(sanitizedPhone)
                .password(passwordEncoder.encode(request.getPassword()))
                .role("ROLE_USER")
                .planType(PlanType.FREE)
                .emailVerified(false)
                .accountStatus("PENDING_VERIFICATION")
                .build();
        user = userRepository.save(user);

        log.info("New user registered in pending verification status: {}", sanitizedUsername);

        // Generate and send OTP
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

        emailService.sendOtpEmail(sanitizedEmail, sanitizedUsername, rawOtp, otpExpiryMinutes);

        return AuthResponse.builder()
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(user.getRole())
                .planType(user.getPlanType().name())
                .sessionVersion(user.getSessionVersion())
                .build();
    }

    @Transactional
    public AuthResponse login(AuthRequest request) {
        String sanitizedIdentifier = Sanitizer.sanitize(request.getUsername()).toLowerCase();

        var user = userRepository.findByUsername(sanitizedIdentifier)
                .or(() -> userRepository.findByEmail(sanitizedIdentifier))
                .or(() -> userRepository.findByPhoneNumber(sanitizedIdentifier))
                // Smart Fallback: Try suffix match if 7-15 digits provided (covers most global local numbers)
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

        // OTP Gating: Block login for unverified accounts
        if (!"ACTIVE".equals(user.getAccountStatus()) || !user.isEmailVerified()) {
            throw new RuntimeException("EMAIL_NOT_VERIFIED:" + user.getEmail());
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        user.getUsername(),
                        request.getPassword()
                )
        );

        userRepository.incrementSessionVersion(user.getUsername());
        long newSessionVersion = user.getSessionVersion() + 1;
        
        webSocketConfig.notifyLogout(user.getUsername());
        
        log.debug("User {} login. Session Version: {} -> {}", user.getUsername(), user.getSessionVersion(), newSessionVersion);

        return authenticate(user, newSessionVersion);
    }

    @Transactional
    public void logout(String username) {
        userRepository.incrementSessionVersion(username);
        log.info("User logged out: {}", username);
    }

    public String issueWSTicket(String username) {
        return wsTicketService.createTicket(username);
    }

    @Transactional(readOnly = true)
    public boolean isUsernameTaken(String username) {
        return userRepository.findByUsername(Sanitizer.sanitize(username).toLowerCase()).isPresent();
    }

    @Transactional(readOnly = true)
    public boolean isEmailTaken(String email) {
        return userRepository.findByEmail(Sanitizer.sanitize(email).toLowerCase()).isPresent();
    }

    @Transactional(readOnly = true)
    public boolean isPhoneTaken(String phone) {
        return userRepository.findByPhoneNumber(Sanitizer.sanitize(phone)).isPresent();
    }

    @Transactional(readOnly = true)
    public AuthResponse getUserProfile(String username) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        boolean hasPendingChanges = user.getPendingEmail() != null || 
                                    user.getPendingUsername() != null || 
                                    user.getPendingPhoneNumber() != null || 
                                    user.getPendingPassword() != null;
        
        return AuthResponse.builder()
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(user.getRole())
                .planType(user.getPlanType().name())
                .sessionVersion(user.getSessionVersion())
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .pendingEmail(user.getPendingEmail() != null ? user.getPendingEmail() : (hasPendingChanges ? user.getEmail() : null))
                .build();
    }

    @Transactional
    public AuthResponse updateProfile(String currentUsername, com.tts.dto.UserProfileUpdateRequest request) {
        var user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 1. Verify Current Password
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        boolean hasChanges = false;

        // Reset previous pending fields (just in case they are stale)
        user.setPendingUsername(null);
        user.setPendingPhoneNumber(null);
        user.setPendingPassword(null);
        user.setPendingEmail(null);

        // 2. Stage Username (if changed)
        if (request.getUsername() != null && !request.getUsername().equalsIgnoreCase(user.getUsername())) {
            String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase();
            if (userRepository.findByUsername(sanitizedUsername).isPresent()) {
                throw new RuntimeException("Username already taken");
            }
            user.setPendingUsername(sanitizedUsername);
            hasChanges = true;
        }

        // 3. Stage Phone Number (if changed)
        if (request.getPhoneNumber() != null && !request.getPhoneNumber().equals(user.getPhoneNumber())) {
            String sanitizedPhone = Sanitizer.sanitize(request.getPhoneNumber());
            if (userRepository.findByPhoneNumber(sanitizedPhone).isPresent()) {
                throw new RuntimeException("Phone number already taken");
            }
            user.setPendingPhoneNumber(sanitizedPhone);
            hasChanges = true;
        }

        // 4. Stage New Password (if provided)
        if (request.getNewPassword() != null && !request.getNewPassword().isBlank()) {
            user.setPendingPassword(passwordEncoder.encode(request.getNewPassword()));
            hasChanges = true;
        }

        // 5. Stage Email (if changed)
        String targetEmail = user.getEmail();
        if (request.getEmail() != null && !request.getEmail().equalsIgnoreCase(user.getEmail())) {
            String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase();
            if (userRepository.findByEmail(sanitizedEmail).isPresent()) {
                throw new RuntimeException("Email already taken");
            }
            user.setPendingEmail(sanitizedEmail);
            targetEmail = sanitizedEmail;
            hasChanges = true;
        }

        if (hasChanges) {
            // Invalidate prior EMAIL_CHANGE OTPs for target email
            otpVerificationRepository.invalidateExistingOtps(targetEmail, "EMAIL_CHANGE");

            // Generate and send OTP to target email
            String rawOtp = generateSecureOtp();
            String otpHash = hashOtp(rawOtp);

            OtpVerification verification = OtpVerification.builder()
                    .user(user)
                    .email(targetEmail)
                    .otpHash(otpHash)
                    .purpose("EMAIL_CHANGE")
                    .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                    .attemptsRemaining(5)
                    .consumed(false)
                    .build();
            otpVerificationRepository.save(verification);

            emailService.sendOtpEmail(targetEmail, user.getUsername(), rawOtp, otpExpiryMinutes);
            log.info("Profile update OTP generated and sent to email: {}", maskEmail(targetEmail));
            
            // Save the staged changes to user entity
            user = userRepository.save(user);
        }

        String role = user.getRole();
        String roleName = role.startsWith("ROLE_") ? role.substring(5) : role;
        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password("")
                .roles(roleName)
                .build();
        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", user.getSessionVersion());
        claims.put("role", role);
        String jwtToken = jwtService.generateToken(claims, userDetails);

        return AuthResponse.builder()
                .token(jwtToken)
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(role)
                .planType(user.getPlanType().name())
                .sessionVersion(user.getSessionVersion())
                .pendingEmail(user.getPendingEmail() != null ? user.getPendingEmail() : (hasChanges ? user.getEmail() : null))
                .build();
    }

    /**
     * Optimized helper to generate a JWT and construct the AuthResponse.
     * Uses the managed User entity directly to ensure data consistency.
     */
    private AuthResponse authenticate(User user, long sessionVersion) {
        String role = user.getRole();
        // Strip ROLE_ prefix if present for UserBuilder.roles() (which adds it back)
        String roleName = role.startsWith("ROLE_") ? role.substring(5) : role;

        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password("") 
                .roles(roleName)
                .build();

        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", sessionVersion);
        claims.put("role", role); 

        var jwtToken = jwtService.generateToken(claims, userDetails);
        return AuthResponse.builder()
                .token(jwtToken)
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(role)
                .planType(user.getPlanType().name())
                .sessionVersion(sessionVersion)
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .pendingEmail(user.getPendingEmail())
                .build();
    }

    @Transactional
    public AuthResponse verifyEmail(VerifyEmailRequest request) {
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        
        OtpVerification verification = otpVerificationRepository
                .findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(sanitizedEmail, "SIGNUP_VERIFICATION")
                .orElseThrow(() -> {
                    log.warn("No active signup verification OTP found for email: {}", maskEmail(sanitizedEmail));
                    return new RuntimeException("Invalid or expired verification code.");
                });

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            log.warn("Signup verification OTP expired for email: {}", maskEmail(sanitizedEmail));
            throw new RuntimeException("Invalid or expired verification code.");
        }

        String checkHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(checkHash)) {
            int attempts = verification.getAttemptsRemaining() - 1;
            verification.setAttemptsRemaining(attempts);
            if (attempts <= 0) {
                verification.setConsumed(true);
                log.warn("Signup verification OTP attempts exhausted for email: {}", maskEmail(sanitizedEmail));
            }
            otpVerificationRepository.save(verification);
            log.warn("Incorrect signup verification OTP attempt for email: {}", maskEmail(sanitizedEmail));
            throw new RuntimeException("Invalid or expired verification code.");
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        User user = userRepository.findByEmail(sanitizedEmail)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setEmailVerified(true);
        user.setAccountStatus("ACTIVE");
        userRepository.save(user);

        log.info("User {} email verified successfully", user.getUsername());
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public void resendOtp(ResendOtpRequest request) {
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        User user = userRepository.findByEmail(sanitizedEmail)
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (user.isEmailVerified()) {
            throw new RuntimeException("Email is already verified.");
        }

        // Invalidate prior OTPs
        otpVerificationRepository.invalidateExistingOtps(sanitizedEmail, "SIGNUP_VERIFICATION");

        // Generate new OTP
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

        emailService.sendOtpEmail(sanitizedEmail, user.getUsername(), rawOtp, otpExpiryMinutes);
        log.info("Verification OTP resent to user: {}", user.getUsername());
    }

    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        Optional<User> userOpt = userRepository.findByEmail(sanitizedEmail);

        if (userOpt.isPresent()) {
            User user = userOpt.get();
            // Invalidate prior
            otpVerificationRepository.invalidateExistingOtps(sanitizedEmail, "PASSWORD_RESET");

            String rawOtp = generateSecureOtp();
            String otpHash = hashOtp(rawOtp);

            OtpVerification verification = OtpVerification.builder()
                    .user(user)
                    .email(sanitizedEmail)
                    .otpHash(otpHash)
                    .purpose("PASSWORD_RESET")
                    .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                    .attemptsRemaining(5)
                    .consumed(false)
                    .build();
                    
            otpVerificationRepository.save(verification);

            emailService.sendOtpEmail(sanitizedEmail, user.getUsername(), rawOtp, otpExpiryMinutes);
            log.info("Password reset OTP generated and sent to email for user: {}", user.getUsername());
        } else {
            // Enforce account enumeration protection by logging only server-side
            log.info("Forgot password requested for non-existing email: {}", maskEmail(sanitizedEmail));
        }
    }

    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        
        OtpVerification verification = otpVerificationRepository
                .findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(sanitizedEmail, "PASSWORD_RESET")
                .orElseThrow(() -> {
                    log.warn("No active OTP found for password reset request on email: {}", maskEmail(sanitizedEmail));
                    return new RuntimeException("Invalid or expired verification code.");
                });

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            log.warn("Password reset OTP expired for email: {}", maskEmail(sanitizedEmail));
            throw new RuntimeException("Invalid or expired verification code.");
        }

        String checkHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(checkHash)) {
            int attempts = verification.getAttemptsRemaining() - 1;
            verification.setAttemptsRemaining(attempts);
            if (attempts <= 0) {
                verification.setConsumed(true);
                log.warn("Password reset OTP attempts exhausted for email: {}", maskEmail(sanitizedEmail));
            }
            otpVerificationRepository.save(verification);
            log.warn("Incorrect password reset OTP attempt for email: {}", maskEmail(sanitizedEmail));
            throw new RuntimeException("Invalid or expired verification code.");
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        User user = userRepository.findByEmail(sanitizedEmail)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        user.setPassword(passwordEncoder.encode(request.getNewPassword()));
        user.setSessionVersion(user.getSessionVersion() + 1);
        userRepository.save(user);

        // Notify session logout for WebSocket connections
        webSocketConfig.notifyLogout(user.getUsername());
        log.info("Password reset successful and sessions invalidated for user: {}", user.getUsername());
    }

    @Transactional
    public AuthResponse verifyEmailChange(String username, VerifyEmailChangeRequest request) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // Determine if we are verifying a pending email change or other profile changes
        String targetEmail = user.getPendingEmail() != null ? user.getPendingEmail() : user.getEmail();
        
        // Safety check: verify that there are actually pending changes
        boolean hasPendingChanges = user.getPendingEmail() != null || 
                                    user.getPendingUsername() != null || 
                                    user.getPendingPhoneNumber() != null || 
                                    user.getPendingPassword() != null;
                                    
        if (!hasPendingChanges) {
            throw new RuntimeException("No pending profile change request found.");
        }

        OtpVerification verification = otpVerificationRepository
                .findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(targetEmail, "EMAIL_CHANGE")
                .orElseThrow(() -> {
                    log.warn("No active OTP found for profile change verification for user: {}", username);
                    return new RuntimeException("Invalid or expired verification code.");
                });

        if (verification.getExpiresAt().isBefore(LocalDateTime.now())) {
            log.warn("Profile change OTP expired for user: {}", username);
            throw new RuntimeException("Invalid or expired verification code.");
        }

        String checkHash = hashOtp(request.getOtp());
        if (!verification.getOtpHash().equals(checkHash)) {
            int attempts = verification.getAttemptsRemaining() - 1;
            verification.setAttemptsRemaining(attempts);
            if (attempts <= 0) {
                verification.setConsumed(true);
                log.warn("Profile change OTP attempts exhausted for user: {}", username);
            }
            otpVerificationRepository.save(verification);
            log.warn("Incorrect profile change OTP verification attempt for user: {}", username);
            throw new RuntimeException("Invalid or expired verification code.");
        }

        verification.setConsumed(true);
        otpVerificationRepository.save(verification);

        // Apply all pending profile updates
        if (user.getPendingUsername() != null) {
            user.setUsername(user.getPendingUsername());
            user.setPendingUsername(null);
        }
        
        if (user.getPendingEmail() != null) {
            user.setEmail(user.getPendingEmail());
            user.setPendingEmail(null);
        }
        
        if (user.getPendingPhoneNumber() != null) {
            user.setPhoneNumber(user.getPendingPhoneNumber());
            user.setPendingPhoneNumber(null);
        }
        
        if (user.getPendingPassword() != null) {
            user.setPassword(user.getPendingPassword());
            user.setPendingPassword(null);
            // Invalidate other sessions on password change
            userRepository.incrementSessionVersion(user.getUsername());
            user.setSessionVersion(user.getSessionVersion() + 1);
            webSocketConfig.notifyLogout(user.getUsername());
        }

        user = userRepository.save(user);
        log.info("User {} successfully verified and updated profile settings.", username);

        String role = user.getRole();
        String roleName = role.startsWith("ROLE_") ? role.substring(5) : role;
        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password("")
                .roles(roleName)
                .build();
        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", user.getSessionVersion());
        claims.put("role", role);
        String jwtToken = jwtService.generateToken(claims, userDetails);

        return AuthResponse.builder()
                .token(jwtToken)
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(role)
                .planType(user.getPlanType().name())
                .sessionVersion(user.getSessionVersion())
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .pendingEmail(null)
                .build();
    }

    private String generateSecureOtp() {
        java.security.SecureRandom random = new java.security.SecureRandom();
        int code = 100000 + random.nextInt(900000);
        return String.valueOf(code);
    }

    private String hashOtp(String otp) {
        try {
            java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(otp.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new RuntimeException("Error hashing OTP", e);
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
