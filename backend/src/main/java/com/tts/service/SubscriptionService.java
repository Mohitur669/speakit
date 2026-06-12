package com.tts.service;

import com.tts.entity.PlanType;
import com.tts.repository.TtsHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

/**
 * Centralizes all subscription-related business rules and feature entitlements.
 * Decouples controllers from specific plan-to-feature mapping logic.
 */
@Service
@RequiredArgsConstructor
public class SubscriptionService {

    private final SystemParameterService systemParameterService;
    private final TtsHistoryRepository ttsHistoryRepository;

    /**
     * Determines the maximum character limit for a given plan.
     */
    public int getMaxCharacters(PlanType planType) {
        if (PlanType.PRO == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_CHARACTERS", "5000"));
        } else if (PlanType.PRO_PLUS == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_PLUS_CHARACTERS", "20000"));
        } else if (PlanType.ENTERPRISE == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_ENTERPRISE_CHARACTERS", "100000"));
        }
        return Integer.parseInt(systemParameterService.getLiveParameter("MAX_FREE_CHARACTERS", "300"));
    }

    /**
     * Checks if the user's plan permits access to ElevenLabs AI voices.
     */
    public boolean canUseElevenLabs(PlanType planType) {
        return PlanType.PRO_PLUS == planType || PlanType.ENTERPRISE == planType;
    }

    /**
     * Checks if the user's plan permits access to Sarvam AI Indian voices.
     */
    public boolean canUseSarvam(PlanType planType) {
        return PlanType.PRO == planType || PlanType.PRO_PLUS == planType || PlanType.ENTERPRISE == planType;
    }

    /**
     * Retrieves the daily synthesis quota for a given plan.
     * Returns -1 for unlimited plans.
     */
    public int getDailySynthesisLimit(PlanType planType) {
        if (PlanType.FREE == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "3"));
        }
        // Paid plans have no daily synthesis limit (only character limits per request)
        return -1;
    }

    /**
     * Validates if the user has reached their daily synthesis quota.
     * Only applies to FREE tier users.
     * 
     * @throws RuntimeException if the limit is exceeded
     */
    public void validateSynthesisLimit(Long userId, PlanType planType) {
        int limit = getDailySynthesisLimit(planType);
        if (limit > 0 && userId != null) {
            LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
            long count = ttsHistoryRepository.countRecentByUserId(userId, todayStart);
            
            if (count >= limit) {
                throw new RuntimeException("Daily limit of " + limit + " syntheses reached for Free plan. Please upgrade to Pro Plus.");
            }
        }
    }
}
