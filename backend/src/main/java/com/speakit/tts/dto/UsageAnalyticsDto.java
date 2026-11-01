package com.speakit.tts.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class UsageAnalyticsDto {

    private String plan;
    private long monthlyLimit;
    private long charactersUsed;
    private long charactersRemaining;
    private double usagePercentage;
    private double burnRatePerDay;
    private double projectedDaysRemaining;
    private int daysRemainingInMonth;
}
