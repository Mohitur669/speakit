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
                String snippet = (text != null && text.length() > 100) ? text.substring(0, 100) : (text != null ? text : "");
                TtsHistory history = TtsHistory.builder()
                        .user(userRepository.getReferenceById(userId))
                        .voiceId(voiceId != null ? voiceId : "unknown")
                        .voiceName(voiceName)
                        .voiceType(voiceType != null ? voiceType : "STANDARD")
                        .outputFormat(format != null ? format : "mp3")
                        .characterCount(charCount)
                        .textSnippet(snippet)
                        .build();
                ttsHistoryRepository.save(history);
            }
        } catch (Exception e) {
            log.warn("Failed to record TTS history, proceeding anyway", e);
        }
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

    public long sumCharactersUsed(Long userId, LocalDateTime since) {
        return ttsHistoryRepository.sumCharactersUsedSince(userId, since);
    }
}
