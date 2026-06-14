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

        // Also check global ElevenLabs feature flag from live parameters
        boolean elevenLabsEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("ELEVENLABS_ENABLED", "true"));
        if (!elevenLabsEnabled) return false;

        return PlanType.PRO_PLUS == planType || PlanType.ENTERPRISE == planType;
    }

    /**
     * Checks if the user's plan permits access to Sarvam AI Indian voices.
     */
    public boolean canUseSarvam(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        if (!hasActivePremiumAccess(planType, status, expiry)) return false;

        // Also check global Sarvam feature flag from live parameters
        boolean sarvamEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("SARVAM_ENABLED", "true"));
        if (!sarvamEnabled) return false;

        return PlanType.PRO == planType || PlanType.PRO_PLUS == planType || PlanType.ENTERPRISE == planType;
    }

    /**
     * Checks if the user's plan permits access to Speech-to-Text (STT) features.
     * Restricted to PRO and above.
     */
    public boolean hasSpeechToText(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        if (!hasActivePremiumAccess(planType, status, expiry)) return false;
        
        // Also check global STT feature flag from live parameters
        boolean sttEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("STT_ENABLED", "true"));
        if (!sttEnabled) return false;

        return planType == PlanType.PRO || planType == PlanType.PRO_PLUS || planType == PlanType.ENTERPRISE;
    }

    /**
     * Returns the maximum allowed audio file size for STT in bytes.
     */
    public long getSttUploadLimitBytes(PlanType planType) {
        long limitMb;
        if (planType == PlanType.PRO) {
            limitMb = Long.parseLong(systemParameterService.getLiveParameter("STT_MAX_FILE_SIZE_MB_PRO", "25"));
        } else if (planType == PlanType.PRO_PLUS) {
            limitMb = Long.parseLong(systemParameterService.getLiveParameter("STT_MAX_FILE_SIZE_MB_PRO_PLUS", "50"));
        } else if (planType == PlanType.ENTERPRISE) {
            limitMb = Long.parseLong(systemParameterService.getLiveParameter("STT_MAX_FILE_SIZE_MB_ENTERPRISE", "500"));
        } else {
            return 0;
        }
        return limitMb * 1024 * 1024;
    }

    /**
     * Returns the maximum allowed audio duration for STT in minutes.
     */
    public int getSttMaxDurationMinutes(PlanType planType) {
        if (planType == PlanType.PRO) {
            return Integer.parseInt(systemParameterService.getLiveParameter("STT_MAX_DURATION_MIN_PRO", "15"));
        } else if (planType == PlanType.PRO_PLUS) {
            return Integer.parseInt(systemParameterService.getLiveParameter("STT_MAX_DURATION_MIN_PRO_PLUS", "30"));
        } else if (planType == PlanType.ENTERPRISE) {
            return Integer.parseInt(systemParameterService.getLiveParameter("STT_MAX_DURATION_MIN_ENTERPRISE", "120"));
        }
        return 0;
    }

    /**
     * Retrieves the daily STT quota for a given plan.
     */
    public int getSttDailyLimit(PlanType planType, SubscriptionStatus status, LocalDateTime expiry) {
        if (!hasSpeechToText(planType, status, expiry)) return 0;
        
        if (planType == PlanType.PRO) {
            return Integer.parseInt(systemParameterService.getLiveParameter("STT_DAILY_QUOTA_PRO", "100"));
        } else if (planType == PlanType.PRO_PLUS) {
            return Integer.parseInt(systemParameterService.getLiveParameter("STT_DAILY_QUOTA_PRO_PLUS", "500"));
        } else if (planType == PlanType.ENTERPRISE) {
            return Integer.parseInt(systemParameterService.getLiveParameter("STT_DAILY_QUOTA_ENTERPRISE", "5000"));
        }
        return 0;
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
