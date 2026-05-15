package com.tts.service;

/**
 * Business logic for user authentication, registration,
 * password encoding, and JWT token generation.
 */
import com.tts.dto.AuthRequest;
import com.tts.dto.AuthResponse;
import com.tts.entity.User;
import com.tts.repository.UserRepository;
import com.tts.security.JwtService;
import com.tts.util.Sanitizer;
import com.tts.config.WebSocketConfig;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Value;

import java.util.HashMap;
import java.util.Map;

@Service
@RequiredArgsConstructor
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

    public AuthResponse register(AuthRequest request) {
        String sanitizedUsername = Sanitizer.sanitize(request.getUsername());
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail());

        var user = User.builder()
                .username(sanitizedUsername)
                .email(sanitizedEmail)
                .password(passwordEncoder.encode(request.getPassword()))
                .hasNaturalVoiceAccess(false)
                .build();
        userRepository.save(user);

        return authenticate(user.getUsername());
    }

    @Transactional
    public AuthResponse login(AuthRequest request) {
        String sanitizedIdentifier = Sanitizer.sanitize(request.getUsername());

        // Find user by username or email
        var user = userRepository.findByUsernameOrEmail(sanitizedIdentifier, sanitizedIdentifier)
                .orElseThrow(() -> new RuntimeException("User not found"));

        authenticationManager.authenticate(
                new UsernamePasswordAuthenticationToken(
                        user.getUsername(),
                        request.getPassword()
                )
        );

        // Increment session version to invalidate previous tokens
        long oldVersion = user.getSessionVersion();
        user.setSessionVersion(oldVersion + 1);
        userRepository.save(user);
        
        // Notify existing sessions to logout immediately
        webSocketConfig.notifyLogout(user.getUsername());
        
        System.out.println("DEBUG: User " + user.getUsername() + " login. Version: " + oldVersion + " -> " + user.getSessionVersion());

        return authenticate(user.getUsername());
    }

    @Transactional
    public void logout(String username) {
        var user = userRepository.findByUsername(username)
                .orElseThrow(() -> new RuntimeException("User not found"));
        user.setSessionVersion(user.getSessionVersion() + 1);
        userRepository.save(user);
    }

    private AuthResponse authenticate(String username) {
        var user = userRepository.findByUsername(username).orElseThrow();
        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(user.getUsername())
                .password(user.getPassword())
                .roles("USER")
                .build();

        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", user.getSessionVersion());

        var jwtToken = jwtService.generateToken(claims, userDetails);
        return AuthResponse.builder()
                .token(jwtToken)
                .username(user.getUsername())
                .hasNaturalVoiceAccess(user.isHasNaturalVoiceAccess())
                .sessionVersion(user.getSessionVersion())
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .build();
    }
}
