package com.speakit.tts.controller;

import com.speakit.tts.dto.AuthResponse;
import com.speakit.tts.dto.UserProfileUpdateRequest;
import com.speakit.tts.dto.VerifyEmailChangeRequest;
import com.shared.aspect.RateLimitAction;
import com.shared.aspect.RateLimited;
import com.speakit.tts.service.AuthService;
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

    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping("/me/cancel-profile-changes")
    public ResponseEntity<AuthResponse> cancelProfileChanges(Principal principal) {
        String username = principal.getName();
        log.info("Cancelling profile changes request for user: {}", username);
        AuthResponse response = authService.cancelProfileChanges(username);
        return ResponseEntity.ok(response);
    }

    @RateLimited(action = RateLimitAction.OTP_RESEND)
    @PostMapping("/me/resend-profile-otp")
    public ResponseEntity<Void> resendProfileOtp(Principal principal) {
        String username = principal.getName();
        log.info("Resending profile update OTP for user: {}", username);
        authService.resendProfileOtp(username);
        return ResponseEntity.ok().build();
    }
}
