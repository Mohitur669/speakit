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
        userRepository.save(user);

        log.info("New user registered: {}", sanitizedUsername);
        return authenticate(user.getUsername());
    }

    @Transactional
    public AuthResponse login(AuthRequest request) {
        String sanitizedIdentifier = Sanitizer.sanitize(request.getUsername()).toLowerCase();

        var user = userRepository.findByUsername(sanitizedIdentifier)
                .or(() -> userRepository.findByEmail(sanitizedIdentifier))
                .or(() -> userRepository.findByPhoneNumber(sanitizedIdentifier))
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

        return authenticate(user.getUsername(), user.getRole(), user.isHasNaturalVoiceAccess(), user.getPlanType(), newSessionVersion);
    }

    @Transactional
    public void logout(String username) {
        userRepository.incrementSessionVersion(username);
        log.info("User logged out: {}", username);
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

    private AuthResponse authenticate(String username, String role, boolean hasNaturalVoiceAccess, String planType, long sessionVersion) {
        // Safe role handling: Default to USER if null
        String effectiveRole = (role != null) ? role : "ROLE_USER";
        
        // Strip ROLE_ prefix if present for UserBuilder.roles() (which adds it back)
        String roleName = effectiveRole.startsWith("ROLE_") ? effectiveRole.substring(5) : effectiveRole;

        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(username)
                .password("") 
                .roles(roleName)
                .build();

        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", sessionVersion);
        claims.put("role", effectiveRole); 

        var user = userRepository.findByUsername(username).orElseThrow();

        var jwtToken = jwtService.generateToken(claims, userDetails);
        return AuthResponse.builder()
                .token(jwtToken)
                .username(username)
                .email(user.getEmail())
                .phoneNumber(user.getPhoneNumber())
                .role(role)
                .hasNaturalVoiceAccess(hasNaturalVoiceAccess)
                .planType(planType)
                .sessionVersion(sessionVersion)
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .build();
    }
    
    private AuthResponse authenticate(String username) {
        var user = userRepository.findByUsername(username).orElseThrow();
        return authenticate(username, user.getRole(), user.isHasNaturalVoiceAccess(), user.getPlanType(), user.getSessionVersion());
    }
}
