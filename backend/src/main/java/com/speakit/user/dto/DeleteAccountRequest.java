package com.speakit.user.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * Request payload for permanent user account deletion.
 * Password re-authentication is verified when provided.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class DeleteAccountRequest {
    private String password;
    private String reason;
}
