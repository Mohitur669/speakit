package com.tts.controller;

import com.tts.aspect.RateLimitAction;
import com.tts.aspect.RateLimited;
import com.tts.dto.AuthRequest;
import com.tts.dto.AuthResponse;
import com.tts.service.AuthService;
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
