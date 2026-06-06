package com.tts.service;

import com.tts.config.WebSocketConfig;
import com.tts.dto.AuthRequest;
import com.tts.dto.AuthResponse;
import com.tts.entity.User;
import com.tts.repository.UserRepository;
import com.tts.security.JwtService;
import com.tts.util.Sanitizer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

/**
 * Handles core authentication flows including user registration, login, 
 * session management, and JWT token provisioning.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final AuthenticationManager authenticationManager;
    private final WebSocketConfig webSocketConfig;
    private final WSTicketService wsTicketService;

    @Value("${auth.session-duration-ms:7200000}")
    private long sessionDurationMs;

    @Value("${auth.idle-timeout-ms:60000}")
    private long idleTimeoutMs;

    @Transactional
    public AuthResponse register(AuthRequest request) {
        String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase();
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase();
        String sanitizedPhone = Sanitizer.sanitize(request.getPhoneNumber());

        var user = User.builder()
                .username(sanitizedUsername)
                .email(sanitizedEmail)
                .phoneNumber(sanitizedPhone)
                .password(passwordEncoder.encode(request.getPassword()))
                .hasNaturalVoiceAccess(false)
                .role("ROLE_USER")
                .planType("FREE")
                .build();
        user = userRepository.save(user);

        log.info("New user registered: {}", sanitizedUsername);
        return authenticate(user, user.getSessionVersion());
    }

    @Transactional
    public AuthResponse login(AuthRequest request) {
        String sanitizedIdentifier = Sanitizer.sanitize(request.getUsername()).toLowerCase();

        var user = userRepository.findByUsername(sanitizedIdentifier)
                .or(() -> userRepository.findByEmail(sanitizedIdentifier))
                .or(() -> userRepository.findByPhoneNumber(sanitizedIdentifier))
                // Smart Fallback: Try suffix match if 7-15 digits provided (covers most global local numbers)
                .or(() -> {
                    if (sanitizedIdentifier.matches("\\d{7,15}")) {
                        return userRepository.findByPhoneNumberSuffix(sanitizedIdentifier);
                    }
                    return Optional.empty();
                })
                .orElseThrow(() -> new RuntimeException("User not found"));

        if (!user.isActive()) {
            throw new RuntimeException("Account is deactivated. Please contact support.");
        }

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        user.getUsername(),
                        request.getPassword()
                )
        );

        userRepository.incrementSessionVersion(user.getUsername());
        long newSessionVersion = user.getSessionVersion() + 1;
        
        webSocketConfig.notifyLogout(user.getUsername());
        
        log.debug("User {} login. Session Version: {} -> {}", user.getUsername(), user.getSessionVersion(), newSessionVersion);

        return authenticate(user, newSessionVersion);
    }

    @Transactional
    public void logout(String username) {
        userRepository.incrementSessionVersion(username);
        log.info("User logged out: {}", username);
    }

    public String issueWSTicket(String username) {
        return wsTicketService.createTicket(username);
    }

    @Transactional(readOnly = true)
    public boolean isUsernameTaken(String username) {
        return userRepository.findByUsername(Sanitizer.sanitize(username).toLowerCase()).isPresent();
    }

    @Transactional(readOnly = true)
    public boolean isEmailTaken(String email) {
        return userRepository.findByEmail(Sanitizer.sanitize(email).toLowerCase()).isPresent();
    }

    @Transactional(readOnly = true)
    public boolean isPhoneTaken(String phone) {
        return userRepository.findByPhoneNumber(Sanitizer.sanitize(phone)).isPresent();
    }

    @Transactional(readOnly = true)
    public AuthResponse getUserProfile(String username) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        
        return AuthResponse.builder()
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(user.getRole())
                .hasNaturalVoiceAccess(user.isHasNaturalVoiceAccess())
                .planType(user.getPlanType())
                .sessionVersion(user.getSessionVersion())
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .build();
    }

    @Transactional
    public AuthResponse updateProfile(String currentUsername, com.tts.dto.UserProfileUpdateRequest request) {
        var user = userRepository.findByUsername(currentUsername)
                .orElseThrow(() -> new RuntimeException("User not found"));

        // 1. Verify Current Password
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPassword())) {
            throw new RuntimeException("Incorrect current password");
        }

        // 2. Validate Uniqueness (if changed)
        if (request.getUsername() != null && !request.getUsername().equalsIgnoreCase(user.getUsername())) {
            String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase();
            if (userRepository.findByUsername(sanitizedUsername).isPresent()) {
                throw new RuntimeException("Username already taken");
            }
            user.setUsername(sanitizedUsername);
        }

        if (request.getEmail() != null && !request.getEmail().equalsIgnoreCase(user.getEmail())) {
            String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase();
            if (userRepository.findByEmail(sanitizedEmail).isPresent()) {
                throw new RuntimeException("Email already taken");
            }
            user.setEmail(sanitizedEmail);
        }

        if (request.getPhoneNumber() != null && !request.getPhoneNumber().equals(user.getPhoneNumber())) {
            String sanitizedPhone = Sanitizer.sanitize(request.getPhoneNumber());
            if (userRepository.findByPhoneNumber(sanitizedPhone).isPresent()) {
                throw new RuntimeException("Phone number already taken");
            }
            user.setPhoneNumber(sanitizedPhone);
        }

        // 3. Update Password (optional)
        if (request.getNewPassword() != null && !request.getNewPassword().isBlank()) {
            user.setPassword(passwordEncoder.encode(request.getNewPassword()));
            // Invalidate other sessions on password change
            userRepository.incrementSessionVersion(user.getUsername());
            user.setSessionVersion(user.getSessionVersion() + 1);
            webSocketConfig.notifyLogout(user.getUsername());
        }

        user = userRepository.save(user);
        log.info("User profile updated for: {}", user.getUsername());
        
        return authenticate(user, user.getSessionVersion());
    }

    /**
     * Optimized helper to generate a JWT and construct the AuthResponse.
     * Uses the managed User entity directly to ensure data consistency.
     */
    private AuthResponse authenticate(User user, long sessionVersion) {
        String role = user.getRole();
        // Strip ROLE_ prefix if present for UserBuilder.roles() (which adds it back)
        String roleName = role.startsWith("ROLE_") ? role.substring(5) : role;

        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password("") 
                .roles(roleName)
                .build();

        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", sessionVersion);
        claims.put("role", role); 

        var jwtToken = jwtService.generateToken(claims, userDetails);
        return AuthResponse.builder()
                .token(jwtToken)
                .username(user.getUsername())
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(role)
                .hasNaturalVoiceAccess(user.isHasNaturalVoiceAccess())
                .planType(user.getPlanType())
                .sessionVersion(sessionVersion)
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .build();
    }
}
