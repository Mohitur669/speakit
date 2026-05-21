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
 * 
 * Includes logic for:
 * - Sanitizing user input to prevent injection
 * - Validating credentials via Spring Security AuthenticationManager
 * - Managing concurrent sessions through DB session_version tracking
 * - Emitting WebSocket events for remote logout enforcement
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

    /**
     * Registers a new user, hashes their password, and provisions an initial JWT.
     * 
     * @param request The un-sanitized registration payload
     * @return AuthResponse containing the JWT token and user session details
     */
    @Transactional
    public AuthResponse register(AuthRequest request) {
        String sanitizedUsername = Sanitizer.sanitize(request.getUsername()).toLowerCase();
        String sanitizedEmail = Sanitizer.sanitize(request.getEmail()).toLowerCase();

        var user = User.builder()
                .username(sanitizedUsername)
                .email(sanitizedEmail)
                .password(passwordEncoder.encode(request.getPassword()))
                .hasNaturalVoiceAccess(false)
                .build();
        userRepository.save(user);

        log.info("New user registered: {}", sanitizedUsername);
        return authenticate(user.getUsername());
    }

    /**
     * Authenticates an existing user and manages session invalidation.
     * 
     * This method increments the user's session_version in the database, ensuring
     * any previously issued JWTs are immediately invalidated (supporting "logout everywhere").
     * It also triggers a WebSocket notification to disconnect active frontend clients.
     * 
     * @param request The login credentials payload
     * @return AuthResponse containing the new JWT token and session details
     */
    @Transactional
    public AuthResponse login(AuthRequest request) {
        String sanitizedIdentifier = Sanitizer.sanitize(request.getUsername()).toLowerCase();

        var user = userRepository.findByUsernameOrEmail(sanitizedIdentifier, sanitizedIdentifier)
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

        // Increment session version to invalidate previous tokens using optimized query
        userRepository.incrementSessionVersion(user.getUsername());
        long newSessionVersion = user.getSessionVersion() + 1;
        
        // Notify existing sessions to logout immediately
        webSocketConfig.notifyLogout(user.getUsername());
        
        log.debug("User {} login. Session Version: {} -> {}", user.getUsername(), user.getSessionVersion(), newSessionVersion);

        return authenticate(user.getUsername(), user.isHasNaturalVoiceAccess(), newSessionVersion);
    }

    /**
     * Increments the user's session_version, effectively logging them out of all devices
     * by invalidating all previously issued JWTs.
     * 
     * @param username The username of the user logging out
     */
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
                .hasNaturalVoiceAccess(user.isHasNaturalVoiceAccess())
                .sessionVersion(user.getSessionVersion())
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .build();
    }

    /**
     * Internal helper to generate a JWT and construct the AuthResponse.
     * Embeds the session_version into the JWT claims for stateless validation.
     */
    private AuthResponse authenticate(String username, boolean hasNaturalVoiceAccess, long sessionVersion) {
        UserDetails userDetails = org.springframework.security.core.userdetails.User.builder()
                .username(username)
                .password("") // Password not needed in token validation flow
                .roles("USER")
                .build();

        Map<String, Object> claims = new HashMap<>();
        claims.put("sessionVersion", sessionVersion);

        var jwtToken = jwtService.generateToken(claims, userDetails);
        return AuthResponse.builder()
                .token(jwtToken)
                .username(username)
                .hasNaturalVoiceAccess(hasNaturalVoiceAccess)
                .sessionVersion(sessionVersion)
                .sessionDurationMs(sessionDurationMs)
                .idleTimeoutMs(idleTimeoutMs)
                .build();
    }
    
    /**
     * Overloaded helper maintained for registration backward compatibility.
     * Performs an extra database read. Prefer the overloaded version with cached attributes.
     */
    private AuthResponse authenticate(String username) {
        var user = userRepository.findByUsername(username).orElseThrow();
        return authenticate(username, user.isHasNaturalVoiceAccess(), user.getSessionVersion());
    }
}
