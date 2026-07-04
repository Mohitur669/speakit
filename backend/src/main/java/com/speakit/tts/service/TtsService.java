package com.speakit.tts.service;
import com.speakit.billing.service.SubscriptionService;

import com.speakit.tts.dto.TtsRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.tts.entity.TtsHistory;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class TtsService {

    private final SubscriptionService subscriptionService;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final UserRepository userRepository;

    @Transactional
    public void recordHistory(Long userId, String voiceId, String voiceName, String voiceType, String format, int charCount, String text) {
        try {
            if (userId != null) {
                TtsHistory history = TtsHistory.builder()
                        .user(userRepository.getReferenceById(userId))
                        .voiceId(voiceId)
                        .voiceName(voiceName)
                        .voiceType(voiceType)
                        .outputFormat(format)
                        .characterCount(charCount)
                        .textSnippet(text.length() > 100 ? text.substring(0, 100) : text)
                        .build();
                ttsHistoryRepository.save(history);
            }
        } catch (Exception e) {
            log.warn("Failed to record TTS history, proceeding anyway", e);
        }
    }

    public void validatePlanAccess(PlanType planType, SubscriptionStatus status, LocalDateTime expiry, TtsRequest request, Long userId) {
        if (request.isElevenLabs() && !subscriptionService.canUseElevenLabs(planType, status, expiry)) {
            throw new RuntimeException("ElevenLabs AI voices require a Pro Plus subscription.");
        }

        if (request.isSarvam() && !subscriptionService.canUseSarvam(planType, status, expiry)) {
            throw new RuntimeException("Sarvam AI Indian voices require a PRO subscription.");
        }

        subscriptionService.validateSynthesisLimit(userId, planType, status, expiry);
    }

    public long countRecentHistory(Long userId, LocalDateTime since) {
        return ttsHistoryRepository.countRecentByUserId(userId, since);
    }
}
