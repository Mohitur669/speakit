package com.tts.service;

import com.tts.entity.PlanType;
import com.tts.entity.SubscriptionStatus;
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
     * Checks if a user has an active entitlement for a premium plan.
     * Considers both the subscription status and potential expiry.
     */
    public boolean hasActivePremiumAccess(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        if (planType == PlanType.FREE) return false;
        
        // Block access for non-active states unless within grace period (handled by status updates)
        if (status == SubscriptionStatus.EXPIRED || status == SubscriptionStatus.SUSPENDED) {
            return false;
        }

        // Final safety check against physical expiry date
        if (expiry != null && expiry.isBefore(LocalDateTime.now())) {
            return false;
        }

        return true;
    }

    /**
     * Determines the maximum character limit for a given plan and its status.
     */
    public int getMaxCharacters(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        // Fallback to FREE limits if subscription is inactive or expired
        if (!hasActivePremiumAccess(planType, status, expiry)) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_FREE_CHARACTERS", "100"));
        }

        if (PlanType.PRO == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_CHARACTERS", "200"));
        } else if (PlanType.PRO_PLUS == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_PLUS_CHARACTERS", "500"));
        } else if (PlanType.ENTERPRISE == planType) {
            return Integer.parseInt(systemParameterService.getLiveParameter("MAX_ENTERPRISE_CHARACTERS", "2000"));
        }
        return Integer.parseInt(systemParameterService.getLiveParameter("MAX_FREE_CHARACTERS", "100"));
    }

    /**
     * Checks if the user's plan permits access to ElevenLabs AI voices.
     */
    public boolean canUseElevenLabs(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        if (!hasActivePremiumAccess(planType, status, expiry)) return false;
        return PlanType.PRO_PLUS == planType || PlanType.ENTERPRISE == planType;
    }

    /**
     * Checks if the user's plan permits access to Sarvam AI Indian voices.
     */
    public boolean canUseSarvam(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        if (!hasActivePremiumAccess(planType, status, expiry)) return false;
        return PlanType.PRO == planType || PlanType.PRO_PLUS == planType || PlanType.ENTERPRISE == planType;
    }

    /**
     * Retrieves the daily synthesis quota for a given plan.
     * Returns -1 for unlimited plans.
     */
    public int getDailySynthesisLimit(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        // If not active premium, they are effectively FREE
        if (!hasActivePremiumAccess(planType, status, expiry)) {
            return Integer.parseInt(systemParameterService.getLiveParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "5"));
        }
        // Paid plans have no daily synthesis limit (only character limits per request)
        return -1;
    }

    /**
     * Validates if the user has reached their daily synthesis quota.
     * Only applies to FREE tier users (or users with inactive premium).
     * 
     * @throws RuntimeException if the limit is exceeded
     */
    public void validateSynthesisLimit(Long userId, PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        int limit = getDailySynthesisLimit(planType, status, expiry);
        if (limit > 0 && userId != null) {
            LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
            long count = ttsHistoryRepository.countRecentByUserId(userId, todayStart);
            
            if (count >= limit) {
                throw new RuntimeException("Daily limit of " + limit + " syntheses reached. Please upgrade to PRO for unlimited generations.");
            }
        }
    }
}
