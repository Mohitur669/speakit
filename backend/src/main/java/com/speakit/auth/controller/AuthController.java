package com.speakit.auth.controller;
import com.speakit.auth.dto.VerifyEmailRequest;
import com.speakit.auth.dto.ResetPasswordRequest;
import com.speakit.auth.dto.ResendOtpRequest;
import com.speakit.auth.dto.ForgotPasswordRequest;
import com.speakit.auth.dto.AuthResponse;
import com.speakit.auth.dto.AuthRequest;
import com.speakit.user.entity.User;

import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import com.speakit.tts.dto.*;
import com.speakit.auth.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

/**
 * Public REST controller managing user authentication lifecycles.
 * 
 * Provides endpoints for:
 * - User registration
 * - JWT-based login
 * - Secure logout (session invalidation)
 * - Platform health checks (ping)
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    /**
     * Registers a new user account and returns an initial authentication token.
     */
    @RateLimited(action = RateLimitAction.AUTH)
    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@RequestBody AuthRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    /**
     * Authenticates existing users and provisions a new JWT session.
     * Triggers concurrent session invalidation internally.
     */
    @RateLimited(action = RateLimitAction.AUTH)
    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@RequestBody AuthRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @RateLimited(action = RateLimitAction.OTP_VERIFY)
    @PostMapping("/verify-email")
    public ResponseEntity<AuthResponse> verifyEmail(@RequestBody VerifyEmailRequest request) {
        return ResponseEntity.ok(authService.verifyEmail(request));
    }

    @RateLimited(action = RateLimitAction.OTP_RESEND)
    @PostMapping("/resend-otp")
    public ResponseEntity<Void> resendOtp(@RequestBody ResendOtpRequest request) {
        authService.resendOtp(request);
        return ResponseEntity.ok().build();
    }

    @RateLimited(action = RateLimitAction.PASSWORD_RESET)
    @PostMapping("/forgot-password")
    public ResponseEntity<Void> forgotPassword(@RequestBody ForgotPasswordRequest request) {
        authService.forgotPassword(request);
        return ResponseEntity.ok().build();
    }

    @RateLimited(action = RateLimitAction.PASSWORD_RESET)
    @PostMapping("/reset-password")
    public ResponseEntity<Void> resetPassword(@RequestBody ResetPasswordRequest request) {
        authService.resetPassword(request);
        return ResponseEntity.ok().build();
    }

    /**
     * Retrieves the current authenticated user's profile and subscription status.
     */
    @GetMapping("/me")
    public ResponseEntity<AuthResponse> getMe() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        return ResponseEntity.ok(authService.getUserProfile(username));
    }

    /**
     * Lightweight endpoint for Render spin-down prevention and basic health monitoring.
     */
    @RateLimited(action = RateLimitAction.PING)
    @GetMapping("/ping")
    public ResponseEntity<Void> ping() {
        return ResponseEntity.ok().build();
    }

    /**
     * Invalidates the current user's session globally by incrementing their session_version.
     */
    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        authService.logout(username);
        return ResponseEntity.ok().build();
    }

    /**
     * Issues a short-lived ticket for secure WebSocket handshakes.
     */
    @PostMapping("/ws-ticket")
    public ResponseEntity<Map<String, String>> getWSTicket() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        String ticket = authService.issueWSTicket(username);
        return ResponseEntity.ok(Map.of("ticket", ticket));
    }

    @RateLimited(action = RateLimitAction.PUBLIC)
    @GetMapping("/check-username")
    public ResponseEntity<Boolean> checkUsername(@RequestParam String username) {
        return ResponseEntity.ok(authService.isUsernameTaken(username));
    }

    @RateLimited(action = RateLimitAction.PUBLIC)
    @GetMapping("/check-email")
    public ResponseEntity<Boolean> checkEmail(@RequestParam String email) {
        return ResponseEntity.ok(authService.isEmailTaken(email));
    }

    @RateLimited(action = RateLimitAction.PUBLIC)
    @GetMapping("/check-phone")
    public ResponseEntity<Boolean> checkPhone(@RequestParam String phone) {
        return ResponseEntity.ok(authService.isPhoneTaken(phone));
    }
}
