package com.speakit.billing.dto;

import com.speakit.billing.entity.PlanType;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class PlanDowngradeRequest {
    private PlanType targetPlan;
}
