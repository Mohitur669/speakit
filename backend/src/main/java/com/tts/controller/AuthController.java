package com.tts.controller;

/**
 * REST controller handling user authentication endpoints
 * for login and registration with JWT token generation.
 */
import com.tts.dto.AuthRequest;
import com.tts.dto.AuthResponse;
import com.tts.service.AuthService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @GetMapping("/session-status")
    public ResponseEntity<Map<String, Long>> getSessionStatus() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        Long version = authService.getSessionVersion(username);
        return ResponseEntity.ok(Map.of("sessionVersion", version));
    }

    @PostMapping("/register")
    public ResponseEntity<AuthResponse> register(@RequestBody AuthRequest request) {
        return ResponseEntity.ok(authService.register(request));
    }

    @PostMapping("/login")
    public ResponseEntity<AuthResponse> login(@RequestBody AuthRequest request) {
        return ResponseEntity.ok(authService.login(request));
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout() {
        String username = SecurityContextHolder.getContext().getAuthentication().getName();
        authService.logout(username);
        return ResponseEntity.ok().build();
    }
}
