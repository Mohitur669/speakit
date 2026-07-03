package com.speakit.stt.controller;

import com.speakit.tts.aspect.RateLimitAction;
import com.speakit.tts.aspect.RateLimited;
import com.speakit.tts.entity.PlanType;
import com.speakit.tts.entity.SubscriptionStatus;
import com.speakit.tts.service.SubscriptionService;
import com.speakit.tts.service.SystemParameterService;
import com.speakit.stt.dto.SpeechToTextResult;
import com.speakit.stt.service.SttService;
import com.speakit.stt.validator.AudioFileValidator;
import com.speakit.stt.dto.TranslationRequest;
import com.speakit.stt.dto.TranslationResponse;
import com.speakit.stt.service.TranslationService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.time.LocalDateTime;

@RestController
@RequestMapping("/api/stt")
@RequiredArgsConstructor
@Slf4j
public class SttController {

    private final SttService sttService;
    private final SubscriptionService subscriptionService;
    private final AudioFileValidator fileValidator;
    private final SystemParameterService systemParameterService;
    private final TranslationService translationService;

    /**
     * Secure endpoint for audio transcription.
     * Restricted to PRO, PRO_PLUS, and ENTERPRISE users.
     */
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping(value = "/transcribe", consumes = "multipart/form-data")
    public ResponseEntity<SpeechToTextResult> transcribe(
            @RequestPart("file") MultipartFile file,
            @RequestPart(value = "language", required = false) String language,
            @RequestPart(value = "provider", required = false) String preferredProvider,
            HttpServletRequest httpRequest
    ) {
        // 1. Global Feature Flag Check (Live Parameter)
        boolean sttEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("STT_ENABLED", "true"));
        if (!sttEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 2. Extract Security Context from Filter attributes
        Long userId = (Long) httpRequest.getAttribute("userId");
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");

        // 3. Plan Authorization (Zero-Trust)
        if (!subscriptionService.hasSpeechToText(planType, status, expiry)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 4. File Validation (MIME, Extension, Malware)
        fileValidator.validate(file);

        // 5. Upload Size Validation (Dynamic per Plan)
        long limitBytes = subscriptionService.getSttUploadLimitBytes(planType);
        if (file.getSize() > limitBytes) {
            String limitMb = systemParameterService.getLiveParameter("STT_MAX_FILE_SIZE_MB_" + planType.name(), "0");
            throw new RuntimeException("File size exceeds your plan limit of " + limitMb + "MB.");
        }

        // 6. Engine Entitlement Check
        // Only PRO_PLUS and above can choose ElevenLabs
        String authorizedProvider = preferredProvider;
        if ("ELEVEN_LABS".equalsIgnoreCase(preferredProvider) && planType == PlanType.PRO) {
            log.warn("User {} (PRO) attempted to use ElevenLabs STT. Forcing Sarvam.", userId);
            authorizedProvider = "SARVAM";
        }

        // 7. Orchestrate Transcription
        SpeechToTextResult result = sttService.transcribe(file, language, userId, authorizedProvider);
        
        return ResponseEntity.ok(result);
    }

    /**
     * Dedicated secure endpoint for live microphone recording transcription.
     * Restricted to PRO_PLUS and ENTERPRISE users.
     */
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping(value = "/transcribe-live", consumes = "multipart/form-data")
    public ResponseEntity<SpeechToTextResult> transcribeLive(
            @RequestPart("file") MultipartFile file,
            @RequestPart(value = "language", required = false) String language,
            @RequestPart(value = "provider", required = false) String preferredProvider,
            HttpServletRequest httpRequest
    ) {
        // 1. Global Feature Flag Check (Live Parameter)
        boolean sttEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("STT_ENABLED", "true"));
        boolean liveRecordingEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("LIVE_RECORDING_ENABLED", "true"));
        if (!sttEnabled || !liveRecordingEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 2. Extract Security Context
        Long userId = (Long) httpRequest.getAttribute("userId");
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");

        // 3. Plan Authorization (Zero-Trust)
        if (!subscriptionService.hasLiveRecording(planType, status, expiry)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 4. File Validation (MIME, Extension, Malware)
        fileValidator.validate(file);

        // 5. Size Validation (Strict 10MB limit for live recording streams)
        if (file.getSize() > 10 * 1024 * 1024) {
            throw new RuntimeException("Live recording size exceeds limit of 10MB.");
        }

        // 6. Engine Entitlement Check
        String authorizedProvider = preferredProvider;
        if ("ELEVEN_LABS".equalsIgnoreCase(preferredProvider) && planType == PlanType.PRO) {
            log.warn("User {} (PRO) attempted to use ElevenLabs STT. Forcing Sarvam.", userId);
            authorizedProvider = "SARVAM";
        }

        // 7. Orchestrate Transcription
        SpeechToTextResult result = sttService.transcribe(file, language, userId, authorizedProvider);
        
        return ResponseEntity.ok(result);
    }

    /**
     * Dedicated translation endpoint for transcribing Speech-to-Text results.
     */
    @RateLimited(action = RateLimitAction.STT)
    @PostMapping("/translate")
    public ResponseEntity<TranslationResponse> translate(
            @RequestBody TranslationRequest request,
            HttpServletRequest httpRequest
    ) {
        // 1. Global Feature Flag Check
        boolean sttEnabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("STT_ENABLED", "true"));
        if (!sttEnabled) {
            return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).build();
        }

        // 2. Extract and authorize plan
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");

        if (!subscriptionService.hasSpeechToText(planType, status, expiry)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }

        // 3. Translate
        TranslationResponse result = translationService.translate(request);
        return ResponseEntity.ok(result);
    }
}
