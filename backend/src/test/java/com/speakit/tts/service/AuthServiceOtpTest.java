package com.speakit.tts.service;
import com.speakit.notification.service.EmailService;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.auth.dto.VerifyEmailChangeRequest;
import com.speakit.auth.dto.VerifyEmailRequest;
import com.speakit.auth.dto.ResetPasswordRequest;
import com.speakit.auth.dto.ForgotPasswordRequest;
import com.speakit.auth.dto.AuthResponse;
import com.speakit.auth.dto.AuthRequest;
import com.speakit.auth.service.AuthService;
import com.speakit.user.dto.UserProfileUpdateRequest;

import com.speakit.config.WebSocketConfig;
import com.speakit.tts.dto.*;
import com.speakit.auth.entity.OtpVerification;
import com.speakit.billing.entity.PlanType;
import com.speakit.user.entity.User;
import com.speakit.auth.repository.OtpVerificationRepository;
import com.speakit.user.repository.UserRepository;
import com.speakit.security.JwtService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AuthServiceOtpTest {

    @InjectMocks
    private AuthService authService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @Mock
    private AuthenticationManager authenticationManager;

    @Mock
    private WebSocketConfig webSocketConfig;

    @Mock
    private WSTicketService wsTicketService;

    @Mock
    private SystemParameterService systemParameterService;

    @Mock
    private OtpVerificationRepository otpVerificationRepository;

    @Mock
    private EmailService emailService;

    private User pendingUser;
    private User activeUser;

    @BeforeEach
    void setUp() {
        org.springframework.test.util.ReflectionTestUtils.setField(authService, "otpExpiryMinutes", 10);
        pendingUser = User.builder()
                .id(1L)
                .username("pendinguser")
                .email("pending@example.com")
                .phoneNumber("9999999999")
                .password("encoded_pass")
                .emailVerified(false)
                .accountStatus("PENDING_VERIFICATION")
                .isActive(true)
                .role("ROLE_USER")
                .planType(PlanType.FREE)
                .sessionVersion(1L)
                .build();

        activeUser = User.builder()
                .id(2L)
                .username("activeuser")
                .email("active@example.com")
                .phoneNumber("8888888888")
                .password("encoded_pass")
                .emailVerified(true)
                .accountStatus("ACTIVE")
                .isActive(true)
                .role("ROLE_USER")
                .planType(PlanType.FREE)
                .sessionVersion(1L)
                .build();
    }

    @Test
    void register_createsPendingUserAndSendsEmail() {
        AuthRequest req = AuthRequest.builder()
                .username("newuser")
                .email("new@example.com")
                .phoneNumber("1234567890")
                .password("password123")
                .build();

        when(passwordEncoder.encode("password123")).thenReturn("hashedpassword");
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AuthResponse response = authService.register(req);

        assertNotNull(response);
        assertNull(response.getToken()); // Token should NOT be issued yet
        assertEquals("newuser", response.getUsername());

        // Verify OTP is generated and saved
        verify(otpVerificationRepository, times(1)).save(any(OtpVerification.class));
        // Verify email is sent
        verify(emailService, times(1)).sendOtpEmail(eq("new@example.com"), eq("newuser"), anyString(), eq(10));
    }

    @Test
    void login_failsForUnverifiedUser() {
        AuthRequest req = AuthRequest.builder()
                .username("pendinguser")
                .password("password123")
                .build();

        when(userRepository.findByUsername("pendinguser")).thenReturn(Optional.of(pendingUser));

        RuntimeException exception = assertThrows(RuntimeException.class, () -> authService.login(req));
        assertTrue(exception.getMessage().startsWith("EMAIL_NOT_VERIFIED"));
    }

    @Test
    void login_succeedsForVerifiedUser() {
        AuthRequest req = AuthRequest.builder()
                .username("activeuser")
                .password("password123")
                .build();

        when(userRepository.findByUsername("activeuser")).thenReturn(Optional.of(activeUser));
        when(jwtService.generateToken(any(), any())).thenReturn("mocked_jwt_token");

        AuthResponse response = authService.login(req);

        assertNotNull(response);
        assertEquals("mocked_jwt_token", response.getToken());
        verify(authenticationManager, times(1)).authenticate(any());
    }

    @Test
    void verifyEmail_success() {
        VerifyEmailRequest req = new VerifyEmailRequest("pending@example.com", "123456");
        
        OtpVerification verification = OtpVerification.builder()
                .email("pending@example.com")
                .otpHash(hashOtp("123456"))
                .purpose("SIGNUP_VERIFICATION")
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .attemptsRemaining(5)
                .consumed(false)
                .build();

        when(otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc("pending@example.com", "SIGNUP_VERIFICATION"))
                .thenReturn(Optional.of(verification));
        when(userRepository.findByEmail("pending@example.com")).thenReturn(Optional.of(pendingUser));
        when(jwtService.generateToken(any(), any())).thenReturn("verified_token");

        AuthResponse response = authService.verifyEmail(req);

        assertNotNull(response);
        assertEquals("verified_token", response.getToken());
        assertTrue(pendingUser.isEmailVerified());
        assertEquals("ACTIVE", pendingUser.getAccountStatus());
        assertTrue(verification.isConsumed());
    }

    @Test
    void verifyEmail_wrongOtpDecrementsAttempts() {
        VerifyEmailRequest req = new VerifyEmailRequest("pending@example.com", "wrong_code");

        OtpVerification verification = OtpVerification.builder()
                .email("pending@example.com")
                .otpHash(hashOtp("123456"))
                .purpose("SIGNUP_VERIFICATION")
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .attemptsRemaining(5)
                .consumed(false)
                .build();

        when(otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc("pending@example.com", "SIGNUP_VERIFICATION"))
                .thenReturn(Optional.of(verification));

        assertThrows(RuntimeException.class, () -> authService.verifyEmail(req));
        assertEquals(4, verification.getAttemptsRemaining());
        assertFalse(verification.isConsumed());
    }

    @Test
    void verifyEmail_attemptsExhaustedConsumesOtp() {
        VerifyEmailRequest req = new VerifyEmailRequest("pending@example.com", "wrong_code");

        OtpVerification verification = OtpVerification.builder()
                .email("pending@example.com")
                .otpHash(hashOtp("123456"))
                .purpose("SIGNUP_VERIFICATION")
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .attemptsRemaining(1)
                .consumed(false)
                .build();

        when(otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc("pending@example.com", "SIGNUP_VERIFICATION"))
                .thenReturn(Optional.of(verification));

        assertThrows(RuntimeException.class, () -> authService.verifyEmail(req));
        assertEquals(0, verification.getAttemptsRemaining());
        assertTrue(verification.isConsumed());
    }

    @Test
    void forgotPassword_doesNotLeakExistence() {
        ForgotPasswordRequest req = new ForgotPasswordRequest("nonexistent@example.com");
        when(userRepository.findByEmail("nonexistent@example.com")).thenReturn(Optional.empty());

        // Should execute without throwing exception (silent success)
        assertDoesNotThrow(() -> authService.forgotPassword(req));
        verify(emailService, never()).sendOtpEmail(anyString(), anyString(), anyString(), anyInt());
    }

    @Test
    void resetPassword_invalidatesActiveSessions() {
        ResetPasswordRequest req = new ResetPasswordRequest("active@example.com", "654321", "newPass123");

        OtpVerification verification = OtpVerification.builder()
                .email("active@example.com")
                .otpHash(hashOtp("654321"))
                .purpose("PASSWORD_RESET")
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .attemptsRemaining(5)
                .consumed(false)
                .build();

        when(otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc("active@example.com", "PASSWORD_RESET"))
                .thenReturn(Optional.of(verification));
        when(userRepository.findByEmail("active@example.com")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.encode("newPass123")).thenReturn("new_encoded_hash");

        authService.resetPassword(req);

        assertEquals("new_encoded_hash", activeUser.getPassword());
        assertEquals(2L, activeUser.getSessionVersion()); // Incremented to invalidate JWTs
        assertTrue(verification.isConsumed());
        verify(webSocketConfig, times(1)).notifyLogout("activeuser");
    }

    @Test
    void updateProfile_emailChangeGeneratesOtp() {
        UserProfileUpdateRequest req = new UserProfileUpdateRequest();
        req.setCurrentPassword("correct_pass");
        req.setEmail("newemail@example.com");

        when(userRepository.findByUsername("activeuser")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("correct_pass", "encoded_pass")).thenReturn(true);
        when(userRepository.findByEmail("newemail@example.com")).thenReturn(Optional.empty());
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        authService.updateProfile("activeuser", req);

        // Current email remains active@example.com until verified
        assertEquals("active@example.com", activeUser.getEmail());
        assertEquals("newemail@example.com", activeUser.getPendingEmail());

        // Verify EMAIL_CHANGE OTP generated and sent to the NEW email
        verify(otpVerificationRepository, times(1)).save(any(OtpVerification.class));
        verify(emailService, times(1)).sendOtpEmail(eq("newemail@example.com"), eq("activeuser"), anyString(), eq(10));
    }

    @Test
    void verifyEmailChange_successUpdatesEmail() {
        VerifyEmailChangeRequest req = new VerifyEmailChangeRequest("987654");
        
        activeUser.setPendingEmail("newemail@example.com");

        OtpVerification verification = OtpVerification.builder()
                .email("newemail@example.com")
                .otpHash(hashOtp("987654"))
                .purpose("EMAIL_CHANGE")
                .expiresAt(LocalDateTime.now().plusMinutes(5))
                .attemptsRemaining(5)
                .consumed(false)
                .build();

        when(userRepository.findByUsername("activeuser")).thenReturn(Optional.of(activeUser));
        when(otpVerificationRepository.findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc("newemail@example.com", "EMAIL_CHANGE"))
                .thenReturn(Optional.of(verification));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));
        when(jwtService.generateToken(anyMap(), any(org.springframework.security.core.userdetails.UserDetails.class))).thenReturn("dummy-token");

        AuthResponse response = authService.verifyEmailChange("activeuser", req);

        assertNotNull(response);
        assertEquals("dummy-token", response.getToken());
        assertEquals("newemail@example.com", activeUser.getEmail());
        assertNull(activeUser.getPendingEmail());
        assertTrue(verification.isConsumed());
    }

    @Test
    void cancelProfileChanges_successClearsPendingAndOtps() {
        activeUser.setPendingEmail("newemail@example.com");
        activeUser.setPendingUsername("newusername");
        activeUser.setPendingPhoneNumber("+15555555555");
        activeUser.setPendingPassword("new_encoded_password");

        when(userRepository.findByUsername("activeuser")).thenReturn(Optional.of(activeUser));
        when(userRepository.save(any(User.class))).thenAnswer(invocation -> invocation.getArgument(0));

        AuthResponse response = authService.cancelProfileChanges("activeuser");

        assertNotNull(response);
        assertNull(activeUser.getPendingEmail());
        assertNull(activeUser.getPendingUsername());
        assertNull(activeUser.getPendingPhoneNumber());
        assertNull(activeUser.getPendingPassword());
        verify(otpVerificationRepository, times(1)).invalidateExistingOtps("active@example.com", "EMAIL_CHANGE");
        verify(otpVerificationRepository, times(1)).invalidateExistingOtps("newemail@example.com", "EMAIL_CHANGE");
    }

    @Test
    void resendProfileOtp_successSendsOtp() {
        activeUser.setPendingEmail("newemail@example.com");

        when(userRepository.findByUsername("activeuser")).thenReturn(Optional.of(activeUser));

        authService.resendProfileOtp("activeuser");

        verify(otpVerificationRepository, times(1)).invalidateExistingOtps("newemail@example.com", "EMAIL_CHANGE");
        verify(otpVerificationRepository, times(1)).save(any(OtpVerification.class));
        verify(emailService, times(1)).sendOtpEmail(eq("newemail@example.com"), eq("activeuser"), anyString(), eq(10));
    }

    private String hashOtp(String otp) {
        try {
            java.security.MessageDigest digest = java.security.MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(otp.getBytes(java.nio.charset.StandardCharsets.UTF_8));
            return java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (java.security.NoSuchAlgorithmException e) {
            throw new RuntimeException(e);
        }
    }
}
