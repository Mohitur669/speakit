package com.tts.controller;

import com.tts.dto.AuthResponse;
import com.tts.dto.UserProfileUpdateRequest;
import com.tts.dto.VerifyEmailChangeRequest;
import com.tts.aspect.RateLimitAction;
import com.tts.aspect.RateLimited;
import com.tts.service.AuthService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;

@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
@Slf4j
public class UserController {

    private final AuthService authService;

    @PutMapping("/profile")
    public ResponseEntity<AuthResponse> updateProfile(
            @RequestBody UserProfileUpdateRequest request,
            Principal principal) {
        
        String username = principal.getName();
        log.info("Profile update request for user: {}", username);
        
        AuthResponse response = authService.updateProfile(username, request);
        return ResponseEntity.ok(response);
    }

    @RateLimited(action = RateLimitAction.OTP_VERIFY)
    @PostMapping("/me/verify-email-change")
    public ResponseEntity<AuthResponse> verifyEmailChange(
            @RequestBody VerifyEmailChangeRequest request,
            Principal principal) {
        
        String username = principal.getName();
        log.info("Verifying email change request for user: {}", username);
        AuthResponse response = authService.verifyEmailChange(username, request);
        return ResponseEntity.ok(response);
    }

    @GetMapping("/me")
    public ResponseEntity<AuthResponse> getCurrentUser(Principal principal) {
        String username = principal.getName();
        AuthResponse response = authService.getUserProfile(username);
        return ResponseEntity.ok(response);
    }
}
