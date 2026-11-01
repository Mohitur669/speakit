package com.speakit.security;

import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.user.repository.UserRepository;
import com.speakit.user.repository.UserSessionProjection;
import com.speakit.user.service.UserSessionCacheService;
import jakarta.servlet.FilterChain;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.context.SecurityContextHolder;

import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class JwtAuthenticationFilterTest {

    @Mock
    private JwtService jwtService;

    @Mock
    private UserSessionCacheService userSessionCacheService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private HttpServletRequest request;

    @Mock
    private HttpServletResponse response;

    @Mock
    private FilterChain filterChain;

    private JwtAuthenticationFilter filter;

    @BeforeEach
    void setUp() {
        SecurityContextHolder.clearContext();
        filter = new JwtAuthenticationFilter(jwtService, userSessionCacheService, userRepository);
    }

    private UserSessionProjection createMockProjection(Long id, Long sessionVersion) {
        return new UserSessionProjection() {
            @Override public Long getId() { return id; }
            @Override public Long getSessionVersion() { return sessionVersion; }
            @Override public PlanType getPlanType() { return PlanType.PRO_PLUS; }
            @Override public SubscriptionStatus getSubscriptionStatus() { return SubscriptionStatus.ACTIVE; }
            @Override public LocalDateTime getPlanExpiry() { return LocalDateTime.now().plusDays(30); }
        };
    }

    @Test
    @DisplayName("Bypasses filter for permitAll endpoints like /api/auth/login")
    void testBypassForLogin() throws Exception {
        when(request.getServletPath()).thenReturn("/api/auth/login");

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verifyNoInteractions(jwtService, userSessionCacheService, userRepository);
    }

    @Test
    @DisplayName("Matches session version from cache: no DB hit and authentication succeeds")
    void testSessionVersionMatchesFromCache() throws Exception {
        when(request.getServletPath()).thenReturn("/api/v1/users/me");
        when(request.getHeader("Authorization")).thenReturn("Bearer valid.token.here");
        when(jwtService.extractUsername("valid.token.here")).thenReturn("mohitur");
        when(jwtService.extractSessionVersion("valid.token.here")).thenReturn(2L);
        when(jwtService.isTokenValid(eq("valid.token.here"), any())).thenReturn(true);

        UserSessionProjection cachedProj = createMockProjection(1L, 2L);
        when(userSessionCacheService.getUserSession("mohitur")).thenReturn(Optional.of(cachedProj));

        filter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verify(userRepository, never()).findSessionAndPlanByUsername(any());
        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals("mohitur", SecurityContextHolder.getContext().getAuthentication().getName());
    }

    @Test
    @DisplayName("Stale cache with session version mismatch falls back to DB and succeeds if DB matches")
    void testStaleCacheFallbackToDbSuccess() throws Exception {
        when(request.getServletPath()).thenReturn("/api/v1/users/me");
        when(request.getHeader("Authorization")).thenReturn("Bearer valid.token.here");
        when(jwtService.extractUsername("valid.token.here")).thenReturn("mohitur");
        when(jwtService.extractSessionVersion("valid.token.here")).thenReturn(3L);
        when(jwtService.isTokenValid(eq("valid.token.here"), any())).thenReturn(true);

        // Cache has stale version 2L
        UserSessionProjection staleProj = createMockProjection(1L, 2L);
        when(userSessionCacheService.getUserSession("mohitur")).thenReturn(Optional.of(staleProj));

        // DB has updated version 3L
        UserSessionProjection freshProj = createMockProjection(1L, 3L);
        when(userRepository.findSessionAndPlanByUsername("mohitur")).thenReturn(Optional.of(freshProj));

        filter.doFilterInternal(request, response, filterChain);

        verify(userSessionCacheService).evictSession("mohitur");
        verify(userRepository).findSessionAndPlanByUsername("mohitur");
        verify(filterChain).doFilter(request, response);
        assertNotNull(SecurityContextHolder.getContext().getAuthentication());
        assertEquals("mohitur", SecurityContextHolder.getContext().getAuthentication().getName());
    }

    @Test
    @DisplayName("True multi-login session eviction: token version differs from DB version")
    void testMultiLoginEviction() throws Exception {
        when(request.getServletPath()).thenReturn("/api/v1/users/me");
        when(request.getHeader("Authorization")).thenReturn("Bearer old.token.here");
        when(jwtService.extractUsername("old.token.here")).thenReturn("mohitur");
        when(jwtService.extractSessionVersion("old.token.here")).thenReturn(1L);

        // Cache has version 2L
        UserSessionProjection staleProj = createMockProjection(1L, 2L);
        when(userSessionCacheService.getUserSession("mohitur")).thenReturn(Optional.of(staleProj));

        // DB has version 2L (token was from previous session version 1L)
        UserSessionProjection freshProj = createMockProjection(1L, 2L);
        when(userRepository.findSessionAndPlanByUsername("mohitur")).thenReturn(Optional.of(freshProj));

        filter.doFilterInternal(request, response, filterChain);

        verify(response).setHeader("X-Logout-Reason", "MULTI_LOGIN");
        verify(response).sendError(HttpServletResponse.SC_UNAUTHORIZED, "Multiple logins detected");
        verify(filterChain, never()).doFilter(request, response);
        assertNull(SecurityContextHolder.getContext().getAuthentication());
    }
}
