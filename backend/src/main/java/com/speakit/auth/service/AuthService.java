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
import com.speakit.user.dto.UpdatePhoneRequest;

import com.speakit.user.service.AvatarStorageService;
import org.springframework.web.multipart.MultipartFile;
import java.io.IOException;

import com.speakit.config.WebSocketConfig;
import com.speakit.tts.dto.*;
import com.speakit.billing.entity.PlanType;
import com.speakit.user.entity.User;
import com.speakit.auth.entity.OtpVerification;
import com.speakit.auth.entity.PendingRegistration;
import com.speakit.user.repository.UserRepository;
import com.speakit.auth.repository.OtpVerificationRepository;
import com.speakit.auth.repository.PendingRegistrationRepository;
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
import org.springframework.scheduling.annotation.Scheduled;

import com.speakit.user.dto.AvatarResponse;
import com.speakit.user.entity.UserAvatarHistory;
import com.speakit.user.repository.UserAvatarHistoryRepository;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.stt.repository.SpeechToTextRequestRepository;
import com.speakit.billing.service.SubscriptionService;
import java.time.temporal.ChronoUnit;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.CompletableFuture;

@Service
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final PendingRegistrationRepository pendingRegistrationRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final OtpVerificationRepository otpVerificationRepository;
    private final OtpEmailSender otpEmailSender;
    private final WSTicketService wsTicketService;
    private final WebSocketConfig webSocketConfig;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final SpeechToTextRequestRepository speechToTextRequestRepository;
    private final SubscriptionService subscriptionService;
    private final AvatarStorageService avatarStorageService;
    private final UserAvatarHistoryRepository userAvatarHistoryRepository;
    private final com.speakit.user.service.UserSessionCacheService userSessionCacheService;

    public AuthService(
            UserRepository userRepository,
            PendingRegistrationRepository pendingRegistrationRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            AuthenticationManager authenticationManager,
            OtpVerificationRepository otpVerificationRepository,
            OtpEmailSender otpEmailSender,
            WSTicketService wsTicketService,
            WebSocketConfig webSocketConfig,
            TtsHistoryRepository ttsHistoryRepository,
            SpeechToTextRequestRepository speechToTextRequestRepository,
            SubscriptionService subscriptionService,
            AvatarStorageService avatarStorageService,
            UserAvatarHistoryRepository userAvatarHistoryRepository,
            @org.springframework.beans.factory.annotation.Autowired(required = false)
            com.speakit.user.service.UserSessionCacheService userSessionCacheService
    ) {
        this.userRepository = userRepository;
        this.pendingRegistrationRepository = pendingRegistrationRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.authenticationManager = authenticationManager;
        this.otpVerificationRepository = otpVerificationRepository;
        this.otpEmailSender = otpEmailSender;
        this.wsTicketService = wsTicketService;
        this.webSocketConfig = webSocketConfig;
        this.ttsHistoryRepository = ttsHistoryRepository;
        this.speechToTextRequestRepository = speechToTextRequestRepository;
        this.subscriptionService = subscriptionService;
        this.avatarStorageService = avatarStorageService;
        this.userAvatarHistoryRepository = userAvatarHistoryRepository;
        this.userSessionCacheService = userSessionCacheService;
    }

    @Value("${auth.session-duration-ms:7200000}")
    private long sessionDurationMs;

    @Value("${auth.idle-timeout-ms:60000}")
    private long idleTimeoutMs;

    @Value("${app.otp.expiry-minutes:10}")
    private int otpExpiryMinutes;

    @Value("${avatar.daily-limit:2}")
    private int avatarDailyLimit;

    @Transactional
    public AuthResponse register(AuthRequest request) {
        String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase().trim();
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();
        String sanitizedPhone = (request.getPhoneNumber() != null && !request.getPhoneNumber().isBlank())
                ? Sanitizer.sanitize(request.getPhoneNumber()).trim()
                : null;
        String sanitizedFullName = (request.getFullName() != null && !request.getFullName().isBlank())
                ? Sanitizer.sanitize(request.getFullName()).trim()
                : null;

        // 1. Conflict check against permanent, verified users in users table
        if (userRepository.findByEmail(sanitizedEmail).isPresent()) {
            throw new RuntimeException("Email already taken");
        }
        if (userRepository.findByUsername(sanitizedUsername).isPresent()) {
            throw new RuntimeException("Username already taken");
        }
        if (sanitizedPhone != null && userRepository.findByPhoneNumber(sanitizedPhone).isPresent()) {
            throw new RuntimeException("Phone number already taken");
        }

        // 2. Conflict check in pending_registrations staging table
        var pendingByUsername = pendingRegistrationRepository.findFirstByUsernameIgnoreCaseAndStatusOrderByCreatedAtDesc(sanitizedUsername, "PENDING");
        if (pendingByUsername.isPresent() && !pendingByUsername.get().getEmail().equalsIgnoreCase(sanitizedEmail)) {
            if (pendingByUsername.get().getExpiresAt().isAfter(LocalDateTime.now())) {
                throw new RuntimeException("Username already taken");
            }
        }

        // 3. Expire previous pending registrations for this email (seamless retry support)
        pendingRegistrationRepository.expireActiveRegistrationsForEmail(sanitizedEmail);

        // 4. Generate secure OTP
        String rawOtp = generateSecureOtp();
        String otpHash = hashOtp(rawOtp);

        // 5. Stage registration in pending_registrations table (primary users table is not touched!)
        PendingRegistration pendingRegistration = PendingRegistration.builder()
                .username(sanitizedUsername)
                .fullName(sanitizedFullName)
                .email(sanitizedEmail)
                .phoneNumber(sanitizedPhone)
                .passwordHash(passwordEncoder.encode(request.getPassword()))
                .otpHash(otpHash)
                .attemptsRemaining(5)
                .status("PENDING")
                .expiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes))
                .build();
        pendingRegistrationRepository.save(pendingRegistration);

        // 6. Send OTP email
        otpEmailSender.sendOtpEmail(sanitizedEmail, sanitizedUsername, rawOtp, otpExpiryMinutes);

        log.info("New registration staged in pending_registrations for email: {}", maskEmail(sanitizedEmail));

        return AuthResponse.builder()
                .username(sanitizedUsername)
                .fullName(sanitizedFullName)
                .email(sanitizedEmail)
                .phoneNumber(sanitizedPhone)
                .role("ROLE_USER")
                .planType(PlanType.FREE.name())
                .subscriptionStatus("ACTIVE")
                .emailVerified(false)
                .avatarDailyLimit(avatarDailyLimit)
                .avatarChangeCount(0)
                .build();
    }

    public AuthResponse login(AuthRequest request) {
        String rawIdentifier = Sanitizer.sanitize(request.getUsername()).trim();
        String sanitizedIdentifier = rawIdentifier.toLowerCase();
        String digitsOnly = rawIdentifier.replaceAll("[^0-9]", "");

        var user = userRepository.findByUsername(sanitizedIdentifier)
                .or(() -> userRepository.findByEmail(sanitizedIdentifier))
                .or(() -> userRepository.findByPhoneNumber(rawIdentifier))
                .or(() -> {
                    if (digitsOnly.length() >= 7 && digitsOnly.length() <= 15) {
                        return userRepository.findByPhoneNumber("+" + digitsOnly)
                                .or(() -> userRepository.findByPhoneNumber(digitsOnly))
                                .or(() -> userRepository.findByPhoneNumberSuffix(digitsOnly));
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

        if (!passwordEncoder.matches(request.getPassword(), user.getPassword())) {
            throw new org.springframework.security.authentication.BadCredentialsException("Bad credentials");
        }

        log.info("User {} logged in successfully", user.getUsername());
        return authenticate(user, user.getSessionVersion());
    }

    public void logout(String username) {
        userRepository.incrementSessionVersion(username);
        if (userSessionCacheService != null) {
            userSessionCacheService.evictSession(username);
        }
        webSocketConfig.notifyLogout(username);
        log.info("User {} logged out, session invalidated", username);
    }

    public String issueWSTicket(String username) {
        return wsTicketService.createTicket(username);
    }

    public boolean isUsernameTaken(String username) {
        String sanitized = Sanitizer.sanitize(username).toLowerCase().trim();
        if (userRepository.findByUsername(sanitized).isPresent()) {
            return true;
        }
        return pendingRegistrationRepository
                .findFirstByUsernameIgnoreCaseAndStatusOrderByCreatedAtDesc(sanitized, "PENDING")
                .filter(p -> p.getExpiresAt().isAfter(LocalDateTime.now()))
                .isPresent();
    }

    public boolean isEmailTaken(String email) {
        String sanitized = Sanitizer.sanitize(email).toLowerCase().trim();
        return userRepository.findByEmail(sanitized).isPresent();
    }

    public boolean isPhoneTaken(String phone) {
        if (phone == null || phone.isBlank()) {
            return false;
        }
        String sanitized = Sanitizer.sanitize(phone).trim();
        return userRepository.findByPhoneNumber(sanitized).isPresent();
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
            String sanitizedPhone = request.getPhoneNumber().isBlank() ? null : Sanitizer.sanitize(request.getPhoneNumber()).trim();
            if (sanitizedPhone != null && userRepository.findByPhoneNumber(sanitizedPhone).isPresent()) {
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
    public AuthResponse updatePhoneNumber(String username, UpdatePhoneRequest request) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        String rawPhone = request != null ? request.getPhoneNumber() : null;
        String sanitizedPhone = (rawPhone == null || rawPhone.isBlank()) ? null : Sanitizer.sanitize(rawPhone).trim();

        if (sanitizedPhone != null) {
            Optional<User> existing = userRepository.findByPhoneNumber(sanitizedPhone);
            if (existing.isPresent() && !existing.get().getId().equals(user.getId())) {
                throw new RuntimeException("Phone number already taken");
            }
        }

        user.setPhoneNumber(sanitizedPhone);
        user = userRepository.save(user);
        log.info("Phone number updated for user: {}", user.getUsername());
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

        // 1. Check pending_registrations staging table (Standard flow)
        var pendingOpt = pendingRegistrationRepository
                .findFirstByEmailIgnoreCaseAndStatusOrderByCreatedAtDesc(sanitizedEmail, "PENDING");

        if (pendingOpt.isPresent()) {
            PendingRegistration pending = pendingOpt.get();

            if (pending.getExpiresAt().isBefore(LocalDateTime.now())) {
                pending.setStatus("EXPIRED");
                pendingRegistrationRepository.save(pending);
                throw new RuntimeException("Verification code has expired. Please request a new one.");
            }

            if (pending.getAttemptsRemaining() <= 0) {
                pending.setStatus("EXPIRED");
                pendingRegistrationRepository.save(pending);
                throw new RuntimeException("Maximum attempts exceeded. Please request a new code.");
            }

            String providedHash = hashOtp(request.getOtp());
            if (!pending.getOtpHash().equals(providedHash)) {
                pending.setAttemptsRemaining(pending.getAttemptsRemaining() - 1);
                pendingRegistrationRepository.save(pending);
                throw new RuntimeException("Invalid verification code. Attempts remaining: " + pending.getAttemptsRemaining());
            }

            // OTP verified! Mark staging record as VERIFIED
            pending.setStatus("VERIFIED");
            pendingRegistrationRepository.save(pending);

            // Double check race condition for unique constraints
            if (userRepository.findByEmail(pending.getEmail()).isPresent()) {
                throw new RuntimeException("Email already taken");
            }
            if (userRepository.findByUsername(pending.getUsername()).isPresent()) {
                throw new RuntimeException("Username already taken");
            }

            // Promote staging record to permanent verified user in users table
            User newUser = User.builder()
                    .username(pending.getUsername())
                    .fullName(pending.getFullName())
                    .email(pending.getEmail())
                    .phoneNumber(pending.getPhoneNumber())
                    .password(pending.getPasswordHash()) // already BCrypt encoded
                    .role("ROLE_USER")
                    .planType(PlanType.FREE)
                    .emailVerified(true)
                    .accountStatus("ACTIVE")
                    .consentAccepted(true)
                    .consentTimestamp(LocalDateTime.now())
                    .build();
            newUser = userRepository.save(newUser);

            log.info("User {} verified and promoted from staging to users table", newUser.getUsername());
            return authenticate(newUser, newUser.getSessionVersion());
        }

        // 2. Legacy fallback for existing users already in users table
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
        String email = Sanitizer.sanitize(request.getEmail()).toLowerCase().trim();

        // 1. Check pending_registrations staging table (Standard flow)
        var pendingOpt = pendingRegistrationRepository
                .findFirstByEmailIgnoreCaseAndStatusOrderByCreatedAtDesc(email, "PENDING");

        if (pendingOpt.isPresent()) {
            PendingRegistration pending = pendingOpt.get();
            String rawOtp = generateSecureOtp();
            pending.setOtpHash(hashOtp(rawOtp));
            pending.setExpiresAt(LocalDateTime.now().plusMinutes(otpExpiryMinutes));
            pending.setAttemptsRemaining(5);
            pendingRegistrationRepository.save(pending);

            otpEmailSender.sendOtpEmail(email, pending.getUsername(), rawOtp, otpExpiryMinutes);
            log.info("Signup OTP resent to pending staging registration for email: {}", maskEmail(email));
            return;
        }

        // 2. Check users table (Legacy unverified fallback)
        Optional<User> userOpt = userRepository.findByEmail(email);
        if (userOpt.isPresent()) {
            User user = userOpt.get();
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
            log.info("Signup OTP resent to legacy unverified user: {}", maskEmail(email));
            return;
        }

        throw new RuntimeException("No pending registration found for this email");
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
        if (userSessionCacheService != null) {
            userSessionCacheService.evictSession(user.getUsername());
        }
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
        if (userSessionCacheService != null) {
            userSessionCacheService.evictSession(user.getUsername());
        }
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

    @Transactional
    public AvatarResponse updateAvatar(String username, MultipartFile file) throws IOException {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        LocalDateTime startOfTodayUtc = java.time.LocalDate.now(java.time.ZoneOffset.UTC).atStartOfDay();
        long currentChangesToday = userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(
                user.getId(),
                "UPLOAD",
                startOfTodayUtc
        );

        if (avatarDailyLimit > 0 && currentChangesToday >= avatarDailyLimit) {
            throw new IllegalArgumentException(String.format(
                "Daily avatar change limit reached. You can only change your profile picture %d times per day. Resets at 00:00 UTC.",
                avatarDailyLimit
            ));
        }

        String oldAvatarUrl = user.getAvatarUrl();
        AvatarStorageService.StoredAvatar stored = avatarStorageService.storeAvatar(user.getId(), file);

        user.setAvatarUrl(stored.url());
        userRepository.save(user);

        if (oldAvatarUrl != null && !oldAvatarUrl.equals(stored.url())) {
            avatarStorageService.deleteAvatar(oldAvatarUrl);
        }

        UserAvatarHistory history = UserAvatarHistory.builder()
                .user(user)
                .avatarUrl(stored.url())
                .storageKey(stored.storageKey())
                .action("UPLOAD")
                .fileSizeBytes(stored.fileSizeBytes())
                .mimeType(stored.mimeType())
                .build();
        userAvatarHistoryRepository.save(history);

        int remainingToday = (int) Math.max(0, avatarDailyLimit - (currentChangesToday + 1));

        return AvatarResponse.builder()
                .avatarUrl(stored.url())
                .storageKey(stored.storageKey())
                .action("UPLOAD")
                .dailyLimit(avatarDailyLimit)
                .remainingChangesToday(remainingToday)
                .updatedAt(LocalDateTime.now(java.time.ZoneOffset.UTC))
                .build();
    }

    @Transactional
    public AvatarResponse deleteAvatar(String username) {
        User user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));

        String oldAvatarUrl = user.getAvatarUrl();
        if (oldAvatarUrl != null) {
            user.setAvatarUrl(null);
            userRepository.save(user);
            avatarStorageService.deleteAvatar(oldAvatarUrl);
        }

        UserAvatarHistory history = UserAvatarHistory.builder()
                .user(user)
                .avatarUrl(null)
                .storageKey(null)
                .action("DELETE")
                .fileSizeBytes(0L)
                .mimeType(null)
                .build();
        userAvatarHistoryRepository.save(history);

        LocalDateTime startOfTodayUtc = java.time.LocalDate.now(java.time.ZoneOffset.UTC).atStartOfDay();
        long uploadsToday = userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(
                user.getId(),
                "UPLOAD",
                startOfTodayUtc
        );
        int remainingToday = (int) Math.max(0, avatarDailyLimit - uploadsToday);

        return AvatarResponse.builder()
                .avatarUrl(null)
                .storageKey(null)
                .action("DELETE")
                .dailyLimit(avatarDailyLimit)
                .remainingChangesToday(remainingToday)
                .updatedAt(LocalDateTime.now(java.time.ZoneOffset.UTC))
                .build();
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
        int avatarChangesToday = 0;

        if (user.getId() != null && ttsHistoryRepository != null && subscriptionService != null) {
            try {
                long t0 = System.currentTimeMillis();
                dailyLimit = subscriptionService.getDailySynthesisLimit(user.getPlanType(), user.getSubscriptionStatus(), user.getPlanExpiry());
                characterLimit = subscriptionService.getMonthlyCharacterLimit(user.getPlanType());
                long tLimits = System.currentTimeMillis() - t0;

                LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
                LocalDateTime monthStart = LocalDateTime.now().withDayOfMonth(1).truncatedTo(ChronoUnit.DAYS);
                LocalDateTime startOfTodayUtc = java.time.LocalDate.now(java.time.ZoneOffset.UTC).atStartOfDay();
                final Long finalUserId = user.getId();

                long tDb0 = System.currentTimeMillis();

                // 1. Daily TTS generation count for today
                dailyCount = (int) ttsHistoryRepository.countRecentByUserId(finalUserId, todayStart);

                // 2. Monthly characters used from atomic UsageLedger (avoids scanning history tables when ledger is up to date)
                java.time.LocalDate currentMonth = java.time.LocalDate.now().withDayOfMonth(1);
                Optional<com.speakit.user.repository.UsageLedgerProjection> ledgerOpt = userRepository != null 
                        ? userRepository.findUsageLedgerById(finalUserId) 
                        : Optional.empty();

                if (ledgerOpt.isPresent() && ledgerOpt.get().getUsageMonth() != null && !ledgerOpt.get().getUsageMonth().isBefore(currentMonth)) {
                    charactersUsed = (int) (ledgerOpt.get().getTtsChars() + ledgerOpt.get().getSttChars());
                } else {
                    // Fallback to table sum only if ledger is uninitialized or in a previous month
                    long ttsChars = ttsHistoryRepository.sumCharactersUsedSince(finalUserId, monthStart);
                    long sttChars = speechToTextRequestRepository != null ? speechToTextRequestRepository.sumCharactersUsedSince(finalUserId, monthStart) : 0L;
                    long ledgerChars = ledgerOpt.map(l -> l.getTtsChars() + l.getSttChars()).orElse(0L);
                    charactersUsed = (int) Math.max(ledgerChars, ttsChars + sttChars);
                }

                // 3. Avatar changes today
                if (userAvatarHistoryRepository != null) {
                    avatarChangesToday = (int) userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(
                            finalUserId, "UPLOAD", startOfTodayUtc);
                }

                log.info("Auth stats timing: limits={}ms, sequentialDbQueries={}ms",
                        tLimits, (System.currentTimeMillis() - tDb0));
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
                .avatarUrl(user.getAvatarUrl())
                .role(user.getRole())
                .planType(user.getPlanType().name())
                .subscriptionStatus(user.getSubscriptionStatus() != null ? user.getSubscriptionStatus().name() : "ACTIVE")
                .planExpiry(user.getPlanExpiry())
                .sessionVersion(sessionVersion)
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .emailVerified(user.isEmailVerified())
                .characterLimit(characterLimit)
                .charactersUsed(charactersUsed)
                .dailyCount(dailyCount)
                .dailyLimit(dailyLimit)
                .avatarDailyLimit(avatarDailyLimit)
                .avatarChangeCount(avatarChangesToday)
                .build();
    }

    /**
     * Periodic maintenance task to expire abandoned staging registrations
     * and purge stale staging audit records older than 30 days (GDPR data minimization).
     */
    @Scheduled(cron = "0 0 3 * * *") // Daily at 3 AM server time
    @Transactional
    public void purgeStaleUnverifiedAccounts() {
        LocalDateTime now = LocalDateTime.now();
        LocalDateTime purgeCutoff = now.minusDays(30);
        try {
            int expiredCount = pendingRegistrationRepository.expireStaleRegistrations(now);
            int deletedPending = pendingRegistrationRepository.deleteExpiredRegistrationsOlderThan(purgeCutoff);
            int deletedOtps = otpVerificationRepository.pruneExpiredOtps(now);

            if (expiredCount > 0 || deletedPending > 0 || deletedOtps > 0) {
                log.info("Staging maintenance: expired {} pending registrations, purged {} stale records (>30d), pruned {} expired OTPs",
                        expiredCount, deletedPending, deletedOtps);
            }
        } catch (Exception e) {
            log.error("Failed to run staging registrations maintenance: {}", e.getMessage(), e);
        }
    }
}
