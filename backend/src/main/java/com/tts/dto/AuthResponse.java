package com.tts.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@AllArgsConstructor
@NoArgsConstructor
public class AuthResponse {
    private String token;
    private String username;
    private String email;
    private String phoneNumber;
    private String role; // ROLE_USER, ROLE_ADMIN
    private boolean hasNaturalVoiceAccess;
    private String planType; // FREE, PRO, ENTERPRISE
    private Long sessionVersion;
    private Long sessionDurationMs;
    private Long idleTimeoutMs;
}
