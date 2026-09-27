package com.speakit.user.service;

import com.speakit.auth.service.AuthService;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.service.SubscriptionService;
import com.speakit.security.JwtService;
import com.speakit.user.dto.AvatarResponse;
import com.speakit.user.entity.User;
import com.speakit.user.entity.UserAvatarHistory;
import com.speakit.user.repository.UserAvatarHistoryRepository;
import com.speakit.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.IOException;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class AvatarDailyLimitTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private UserAvatarHistoryRepository userAvatarHistoryRepository;

    @Mock
    private AvatarStorageService avatarStorageService;

    @Mock
    private JwtService jwtService;

    @Mock
    private SubscriptionService subscriptionService;

    @InjectMocks
    private AuthService authService;

    private User testUser;
    private MockMultipartFile mockFile;

    @BeforeEach
    void setUp() {
        ReflectionTestUtils.setField(authService, "avatarDailyLimit", 2);
        ReflectionTestUtils.setField(authService, "sessionDurationMs", 7200000L);
        ReflectionTestUtils.setField(authService, "idleTimeoutMs", 60000L);

        testUser = User.builder()
                .id(101L)
                .username("testcoder")
                .fullName("Test Coder")
                .email("test@speakit.local")
                .password("encoded_pass")
                .role("ROLE_USER")
                .planType(PlanType.FREE)
                .subscriptionStatus(SubscriptionStatus.ACTIVE)
                .sessionVersion(1L)
                .build();

        mockFile = new MockMultipartFile("file", "test.jpg", "image/jpeg", new byte[]{1, 2, 3});
    }

    @Test
    @DisplayName("Should allow avatar upload when user has not changed avatar today and return minimal AvatarResponse")
    void shouldAllowAvatarChangeWhenNoChangesToday() throws IOException {
        when(userRepository.findByUsername("testcoder")).thenReturn(Optional.of(testUser));
        when(userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(eq(101L), eq("UPLOAD"), any()))
                .thenReturn(0L);
        when(avatarStorageService.storeAvatar(eq(101L), any()))
                .thenReturn(new AvatarStorageService.StoredAvatar("https://cdn.speakit.com/avatars/u_101_1.jpg", "avatars/u_101_1.jpg", 1024L, "image/jpeg"));

        AvatarResponse response = authService.updateAvatar("testcoder", mockFile);

        assertNotNull(response);
        assertEquals("https://cdn.speakit.com/avatars/u_101_1.jpg", response.getAvatarUrl());
        assertEquals("avatars/u_101_1.jpg", response.getStorageKey());
        assertEquals("UPLOAD", response.getAction());
        assertEquals(2, response.getDailyLimit());
        assertEquals(1, response.getRemainingChangesToday());
        assertNotNull(response.getUpdatedAt());

        verify(userAvatarHistoryRepository).save(any(UserAvatarHistory.class));
        verify(userRepository).save(testUser);
        assertEquals("https://cdn.speakit.com/avatars/u_101_1.jpg", testUser.getAvatarUrl());
    }

    @Test
    @DisplayName("Should allow second avatar upload up to the limit of 2")
    void shouldAllowSecondAvatarChangeUpToLimit() throws IOException {
        when(userRepository.findByUsername("testcoder")).thenReturn(Optional.of(testUser));
        when(userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(eq(101L), eq("UPLOAD"), any()))
                .thenReturn(1L);
        when(avatarStorageService.storeAvatar(eq(101L), any()))
                .thenReturn(new AvatarStorageService.StoredAvatar("https://cdn.speakit.com/avatars/u_101_2.jpg", "avatars/u_101_2.jpg", 1024L, "image/jpeg"));

        AvatarResponse response = authService.updateAvatar("testcoder", mockFile);

        assertNotNull(response);
        assertEquals(2, response.getDailyLimit());
        assertEquals(0, response.getRemainingChangesToday());
        verify(userAvatarHistoryRepository).save(any(UserAvatarHistory.class));
    }

    @Test
    @DisplayName("Should block avatar upload when daily limit of 2 is reached")
    void shouldBlockAvatarChangeWhenLimitExceeded() throws IOException {
        when(userRepository.findByUsername("testcoder")).thenReturn(Optional.of(testUser));
        when(userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(eq(101L), eq("UPLOAD"), any()))
                .thenReturn(2L);

        IllegalArgumentException ex = assertThrows(IllegalArgumentException.class, () ->
                authService.updateAvatar("testcoder", mockFile)
        );

        assertTrue(ex.getMessage().contains("Daily avatar change limit reached"));
        assertTrue(ex.getMessage().contains("2 times per day"));
        verify(avatarStorageService, never()).storeAvatar(any(), any());
        verify(userAvatarHistoryRepository, never()).save(any());
    }

    @Test
    @DisplayName("Should log DELETE action in history and not consume upload quota")
    void shouldLogDeleteAction() {
        testUser.setAvatarUrl("https://cdn.speakit.com/avatars/u_101_old.jpg");
        when(userRepository.findByUsername("testcoder")).thenReturn(Optional.of(testUser));
        when(userAvatarHistoryRepository.countByUserIdAndActionAndCreatedAtGreaterThanEqual(eq(101L), eq("UPLOAD"), any()))
                .thenReturn(1L);

        AvatarResponse response = authService.deleteAvatar("testcoder");

        assertNotNull(response);
        assertNull(response.getAvatarUrl());
        assertNull(response.getStorageKey());
        assertEquals("DELETE", response.getAction());
        assertEquals(1, response.getRemainingChangesToday());

        assertNull(testUser.getAvatarUrl());
        verify(avatarStorageService).deleteAvatar("https://cdn.speakit.com/avatars/u_101_old.jpg");
        verify(userAvatarHistoryRepository).save(any(UserAvatarHistory.class));
    }
}
