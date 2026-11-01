package com.speakit.tts.service;

import com.speakit.billing.service.SubscriptionService;
import org.jspecify.annotations.Nullable;

import com.speakit.tts.dto.TtsRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.tts.entity.TtsHistory;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.user.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.LocalDateTime;

@Service
@Slf4j
public class TtsService {

    private final SubscriptionService subscriptionService;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final UserRepository userRepository;

    public TtsService(
            SubscriptionService subscriptionService,
            TtsHistoryRepository ttsHistoryRepository,
            UserRepository userRepository) {
        this.subscriptionService = subscriptionService;
        this.ttsHistoryRepository = ttsHistoryRepository;
        this.userRepository = userRepository;
    }

    @Transactional
    public void recordHistory(Long userId, String voiceId, String voiceName, String voiceType, String format, int charCount, String text) {
        recordHistory(userId, voiceId, voiceName, voiceType, format, charCount, text, null, null);
    }

    @Transactional
    public @Nullable TtsHistory recordHistory(Long userId, String voiceId, String voiceName, String voiceType, String format, int charCount, String text, String audioUrl, String storageKey) {
        try {
            if (userId != null) {
                String snippet = (text != null && text.length() > 100) ? text.substring(0, 100) : (text != null ? text : "");
                TtsHistory history = TtsHistory.builder()
                        .user(userRepository.getReferenceById(userId))
                        .voiceId(voiceId != null ? voiceId : "unknown")
                        .voiceName(voiceName)
                        .voiceType(voiceType != null ? voiceType : "STANDARD")
                        .outputFormat(format != null ? format : "mp3")
                        .characterCount(charCount)
                        .textSnippet(snippet)
                        .fullText(text)
                        .audioUrl(audioUrl)
                        .storageKey(storageKey)
                        .build();
                TtsHistory saved = ttsHistoryRepository.save(history);

                // Atomically increment the usage ledger — this is the source-of-truth
                // for billing. History rows are display-only; deleting them must never
                // affect the reported character count.
                if (charCount > 0) {
                    userRepository.incrementTtsCharsUsed(userId, charCount, LocalDate.now().withDayOfMonth(1));
                }

                return saved;
            }
        } catch (Exception e) {
            log.warn("Failed to record TTS history, proceeding anyway", e);
        }
        return null;
    }

    public void validatePlanAccess(PlanType planType, SubscriptionStatus status, LocalDateTime expiry, TtsRequest request, Long userId) {
        if (request.isElevenLabs() && !subscriptionService.canUseElevenLabs(planType, status, expiry)) {
            throw new RuntimeException("International AI voices require a Pro Plus subscription.");
        }

        if (request.isSarvam() && !subscriptionService.canUseSarvam(planType, status, expiry)) {
            throw new RuntimeException("Indian AI voices require a PRO subscription.");
        }

        subscriptionService.validateSynthesisLimit(userId, planType, status, expiry);
    }

    public long countRecentHistory(Long userId, LocalDateTime since) {
        return ttsHistoryRepository.countRecentByUserId(userId, since);
    }

    /**
     * Returns the total characters consumed by the user this billing month.
     *
     * <p>Reads from the write-forward usage ledger columns on the users table —
     * NOT from history rows — so deleting history entries never affects this value.
     * Auto-resets to 0 when a new calendar month is detected (via usageMonth comparison).
     */
    public long sumCharactersUsed(Long userId, LocalDateTime since) {
        LocalDate currentMonth = LocalDate.now().withDayOfMonth(1);

        return userRepository.findUsageLedgerById(userId)
                .map(ledger -> {
                    // If the stored month is behind the current month, the counters
                    // belong to the previous month — treat them as 0 for this month.
                    if (ledger.getUsageMonth().isBefore(currentMonth)) {
                        return 0L;
                    }
                    return ledger.getTtsChars() + ledger.getSttChars();
                })
                .orElse(0L);
    }

    public com.speakit.tts.dto.UsageAnalyticsDto getUsageAnalytics(Long userId, PlanType planType) {
        LocalDate today = LocalDate.now();
        LocalDate currentMonth = today.withDayOfMonth(1);
        int daysInMonth = today.lengthOfMonth();
        int dayOfMonth = today.getDayOfMonth();
        int daysRemainingInMonth = Math.max(0, daysInMonth - dayOfMonth);

        long charactersUsed = sumCharactersUsed(userId, currentMonth.atStartOfDay());
        long monthlyLimit = subscriptionService.getMonthlyCharacterLimit(planType);
        long charactersRemaining = Math.max(0, monthlyLimit - charactersUsed);
        double usagePercentage = monthlyLimit > 0 ? ((double) charactersUsed / monthlyLimit) : 0.0;

        int daysElapsed = Math.max(1, dayOfMonth);
        double burnRatePerDay = (double) charactersUsed / daysElapsed;
        double projectedDaysRemaining = burnRatePerDay > 0
                ? (charactersRemaining / burnRatePerDay)
                : daysRemainingInMonth;

        return com.speakit.tts.dto.UsageAnalyticsDto.builder()
                .plan(planType != null ? planType.name() : "FREE")
                .monthlyLimit(monthlyLimit)
                .charactersUsed(charactersUsed)
                .charactersRemaining(charactersRemaining)
                .usagePercentage(Math.round(usagePercentage * 1000.0) / 10.0)
                .burnRatePerDay(Math.round(burnRatePerDay * 10.0) / 10.0)
                .projectedDaysRemaining(Math.round(projectedDaysRemaining * 10.0) / 10.0)
                .daysRemainingInMonth(daysRemainingInMonth)
                .build();
    }
}
