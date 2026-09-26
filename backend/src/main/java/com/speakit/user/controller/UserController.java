package com.speakit.user.controller;

import com.speakit.auth.dto.AuthResponse;
import com.speakit.auth.dto.ChangePasswordRequest;
import com.speakit.auth.dto.RequestPasswordChangeOtpRequest;
import com.speakit.auth.dto.VerifyEmailChangeRequest;
import com.speakit.user.dto.RequestEmailChangeOtpRequest;
import com.speakit.user.dto.RequestProfileUpdateRequest;
import com.speakit.user.dto.UpdateEmailRequest;
import com.speakit.user.dto.UpdateFullNameRequest;
import com.speakit.user.dto.UpdateUsernameRequest;
import com.speakit.user.dto.UserProfileUpdateRequest;
import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import com.speakit.auth.service.AuthService;
import jakarta.validation.Valid;
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

    // MARK: - Legacy / Combined Profile Update (Backward Compatibility)
    @PutMapping("/profile")
    public ResponseEntity<AuthResponse> updateProfile(
            @RequestBody UserProfileUpdateRequest request,
            Principal principal) {
        
        String username = principal.getName();
        log.info("Profile update request for user: {}", username);
        
        AuthResponse response = authService.updateProfile(username, request);
        return ResponseEntity.ok(response);
    }

    // MARK: - Separated Full Name Update
    @PutMapping("/full-name")
    public ResponseEntity<AuthResponse> updateFullName(
            @Valid @RequestBody UpdateFullNameRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Updating full name for user: {}", username);
        AuthResponse response = authService.updateFullName(username, request);
        return ResponseEntity.ok(response);
    }

    // MARK: - Separated Username Update
    @PutMapping("/username")
    public ResponseEntity<AuthResponse> updateUsername(
            @Valid @RequestBody UpdateUsernameRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Updating username for user: {}", username);
        AuthResponse response = authService.updateUsername(username, request);
        return ResponseEntity.ok(response);
    }

    // MARK: - Separated Email Update (Password Verified Before OTP Dispatch)
    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping("/email/request-otp")
    public ResponseEntity<Void> requestEmailChangeOtp(
            @Valid @RequestBody RequestEmailChangeOtpRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Requesting email change OTP for user: {}", username);
        authService.requestEmailChangeOtp(username, request.getCurrentPassword());
        return ResponseEntity.ok().build();
    }

    @RateLimited(action = RateLimitAction.OTP_VERIFY)
    @PutMapping("/email")
    public ResponseEntity<AuthResponse> updateEmail(
            @Valid @RequestBody UpdateEmailRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Updating email for user: {}", username);
        AuthResponse response = authService.updateEmail(username, request);
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

    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping("/profile/request-update")
    public ResponseEntity<Void> requestProfileUpdate(
            @RequestBody(required = false) RequestProfileUpdateRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Requesting profile update OTP for user: {}", username);
        String currentPassword = (request != null) ? request.getCurrentPassword() : null;
        authService.requestProfileUpdate(username, currentPassword);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/me")
    public ResponseEntity<AuthResponse> getCurrentUser(Principal principal) {
        String username = principal.getName();
        AuthResponse response = authService.getUserProfile(username);
        return ResponseEntity.ok(response);
    }

    @RateLimited(action = RateLimitAction.PASSWORD_RESET)
    @PostMapping("/password/request-otp")
    public ResponseEntity<Void> requestPasswordChangeOtp(
            @RequestBody RequestPasswordChangeOtpRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Requesting password change OTP for user: {}", username);
        authService.requestPasswordChangeOtp(username, request.getCurrentPassword());
        return ResponseEntity.ok().build();
    }

    // MARK: - Separated Password Change (Supports both /password and /change-password)
    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping({"/password", "/change-password"})
    public ResponseEntity<Void> changePassword(
            @RequestBody ChangePasswordRequest request,
            Principal principal) {
        String username = principal.getName();
        log.info("Changing password for user: {}", username);
        authService.changePassword(username, request);
        return ResponseEntity.ok().build();
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
