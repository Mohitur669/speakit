package com.speakit.user.service;

import com.speakit.auth.repository.OtpVerificationRepository;
import com.speakit.auth.repository.PendingRegistrationRepository;
import com.speakit.auth.service.AuthService;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.repository.SubscriptionRepository;
import com.speakit.billing.service.SubscriptionService;
import com.speakit.config.WebSocketConfig;
import com.speakit.notification.repository.LogBackupAuditRepository;
import com.speakit.notification.service.DiscordService;
import com.speakit.notification.service.EmailService;
import com.speakit.notification.service.OtpEmailSender;
import com.speakit.security.JwtService;
import com.speakit.stt.repository.LiveSessionTurnRepository;
import com.speakit.stt.repository.SpeechToTextRequestRepository;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.tts.service.WSTicketService;
import com.speakit.user.controller.UserController;
import com.speakit.user.dto.DeleteAccountRequest;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserAvatarHistoryRepository;
import com.speakit.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.security.Principal;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AccountDeletionTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PendingRegistrationRepository pendingRegistrationRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @Mock
    private OtpVerificationRepository otpVerificationRepository;

    @Mock
    private OtpEmailSender otpEmailSender;

    @Mock
    private WSTicketService wsTicketService;

    @Mock
    private WebSocketConfig webSocketConfig;

    @Mock
    private TtsHistoryRepository ttsHistoryRepository;

    @Mock
    private SpeechToTextRequestRepository speechToTextRequestRepository;

    @Mock
    private SubscriptionService subscriptionService;

    @Mock
    private AvatarStorageService avatarStorageService;

    @Mock
    private UserAvatarHistoryRepository userAvatarHistoryRepository;

    @Mock
    private UserSessionCacheService userSessionCacheService;

    @Mock
    private LiveSessionTurnRepository liveSessionTurnRepository;

    @Mock
    private SubscriptionRepository subscriptionRepository;

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private LogBackupAuditRepository logBackupAuditRepository;

    @Mock
    private EmailService emailService;

    @Mock
    private DiscordService discordService;

    private AuthService authService;
    private UserController userController;
    private User testUser;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userRepository,
                pendingRegistrationRepository,
                passwordEncoder,
                jwtService,
                otpVerificationRepository,
                otpEmailSender,
                wsTicketService,
                webSocketConfig,
                ttsHistoryRepository,
                speechToTextRequestRepository,
                subscriptionService,
                avatarStorageService,
                userAvatarHistoryRepository,
                userSessionCacheService,
                liveSessionTurnRepository,
                subscriptionRepository,
                paymentRepository,
                logBackupAuditRepository,
                emailService,
                discordService
        );

        userController = new UserController(authService);

        testUser = User.builder()
                .id(101L)
                .username("testuser")
                .email("testuser@speakit.com")
                .fullName("Test User")
                .password("$2a$10$hashedPassword")
                .avatarUrl("https://r2.speakit.local/avatars/101.png")
                .planType(PlanType.PRO)
                .subscriptionStatus(SubscriptionStatus.ACTIVE)
                .sessionVersion(1L)
                .build();
    }

    @Test
    @DisplayName("Cascading account deletion purges personal data and anonymizes financial records per DPDP Act")
    void testCascadingAccountDeletion_Successful() {
        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(testUser));

        Map<String, String> response = authService.deleteAccount("testuser", null);

        assertNotNull(response);
        assertEquals("DELETED", response.get("status"));

        // 1. Financial anonymization
        verify(paymentRepository, times(1)).anonymizePaymentsByUserId(101L);
        verify(subscriptionRepository, times(1)).anonymizeSubscriptionsByUserId(101L);
        verify(logBackupAuditRepository, times(1)).disassociateUserFromAudits(101L);

        // 2. Personal data cascade
        verify(avatarStorageService, times(1)).deleteAvatar("https://r2.speakit.local/avatars/101.png");
        verify(userAvatarHistoryRepository, times(1)).deleteAllByUserId(101L);
        verify(ttsHistoryRepository, times(1)).deleteAllByUserId(101L);
        verify(liveSessionTurnRepository, times(1)).deleteAllByUserId(101L);
        verify(speechToTextRequestRepository, times(1)).deleteAllByUserId(101L);
        verify(otpVerificationRepository, times(1)).deleteAllByUserIdOrEmail(101L, "testuser@speakit.com");

        // 3. Session eviction
        verify(userSessionCacheService, times(1)).evictSession("testuser");

        // 4. Notifications & Alerts
        verify(emailService, times(1)).sendAccountDeletionEmail("testuser@speakit.com", "testuser");
        verify(discordService, times(1)).sendAccountDeletionAlert(eq("testuser"), eq(101L), eq("testuser@speakit.com"), any());

        // 5. Final User delete
        verify(userRepository, times(1)).delete(testUser);
    }

    @Test
    @DisplayName("Cascading account deletion succeeds with valid re-auth password")
    void testCascadingAccountDeletion_WithValidPassword() {
        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(testUser));
        when(passwordEncoder.matches("ValidPassword123!", "$2a$10$hashedPassword")).thenReturn(true);

        DeleteAccountRequest request = DeleteAccountRequest.builder()
                .password("ValidPassword123!")
                .reason("No longer needed")
                .build();

        Map<String, String> response = authService.deleteAccount("testuser", request);

        assertNotNull(response);
        assertEquals("DELETED", response.get("status"));
        verify(userRepository, times(1)).delete(testUser);
    }

    @Test
    @DisplayName("Cascading account deletion rejects invalid re-auth password with BadCredentialsException")
    void testCascadingAccountDeletion_WithInvalidPassword_ThrowsBadCredentials() {
        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(testUser));
        when(passwordEncoder.matches("WrongPassword", "$2a$10$hashedPassword")).thenReturn(false);

        DeleteAccountRequest request = DeleteAccountRequest.builder()
                .password("WrongPassword")
                .reason("Test")
                .build();

        assertThrows(BadCredentialsException.class, () -> authService.deleteAccount("testuser", request));

        // Ensure nothing was deleted or anonymized
        verify(userRepository, never()).delete(any());
        verify(paymentRepository, never()).anonymizePaymentsByUserId(anyLong());
        verify(ttsHistoryRepository, never()).deleteAllByUserId(anyLong());
    }

    @Test
    @DisplayName("Cascading account deletion throws UsernameNotFoundException when user does not exist")
    void testCascadingAccountDeletion_UserNotFound() {
        when(userRepository.findByUsername("unknown")).thenReturn(Optional.empty());

        assertThrows(UsernameNotFoundException.class, () -> authService.deleteAccount("unknown", null));
        verify(userRepository, never()).delete(any());
    }

    @Test
    @DisplayName("UserController DELETE /api/v1/users/me executes and returns 200 OK")
    void testUserController_DeleteAccount() {
        when(userRepository.findByUsername("testuser")).thenReturn(Optional.of(testUser));

        Principal principal = () -> "testuser";
        ResponseEntity<Map<String, String>> response = userController.deleteAccount(null, principal);

        assertNotNull(response);
        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertEquals("DELETED", response.getBody().get("status"));
    }
}
