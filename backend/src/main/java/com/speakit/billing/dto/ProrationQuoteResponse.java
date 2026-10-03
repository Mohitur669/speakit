package com.speakit.billing.dto;

import com.speakit.billing.entity.PlanType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;

/**
 * DTO carrying proration quotation details for plan upgrades and changes.
 * Calculates credit adjustments based on remaining days of active subscriptions.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class ProrationQuoteResponse {
    private PlanType currentPlan;
    private PlanType targetPlan;
    private BigDecimal currentPlanPrice;
    private BigDecimal targetPlanPrice;
    private long remainingDays;
    private long totalDays;
    private BigDecimal unusedCredit;
    private BigDecimal amountToPay;
    private String currency;
    private boolean isUpgrade;
    private String description;
}
