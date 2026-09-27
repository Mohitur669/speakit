package com.speakit.user.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UserProfileUpdateRequest {
    private String fullName;
    private String username;
    private String email;
    private String phoneNumber;
    private String currentPassword;
    private String newPassword;
    private String otp;
}
