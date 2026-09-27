package com.speakit.user.dto;

import com.fasterxml.jackson.annotation.JsonInclude;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
@JsonInclude(JsonInclude.Include.NON_NULL)
public class AvatarResponse {
    private String avatarUrl;
    private String storageKey;
    private String action; // "UPLOAD" or "DELETE"
    private int dailyLimit;
    private int remainingChangesToday;
    private LocalDateTime updatedAt;
}
