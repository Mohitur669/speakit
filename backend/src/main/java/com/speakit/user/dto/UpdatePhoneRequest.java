package com.speakit.user.dto;

import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UpdatePhoneRequest {
    @Size(max = 20, message = "Phone number must be at most 20 characters")
    @Pattern(regexp = "^$|^[+]?[0-9\\s-]{7,15}$", message = "Invalid phone number format")
    private String phoneNumber;
}
