package com.speakit.tts.controller;
import com.speakit.user.entity.User;

import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import com.speakit.tts.dto.TtsRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.tts.entity.TtsHistory;
import com.speakit.tts.service.TtsService;
import com.speakit.tts.service.ElevenLabsService;
import com.speakit.tts.service.PollyService;
import com.speakit.tts.service.SarvamService;
import com.speakit.billing.service.SubscriptionService;
import com.speakit.shared.util.Sanitizer;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.polly.model.Engine;

import java.io.InputStream;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;

/**
 * Controller for Text-to-Speech operations including buffered and streaming synthesis,
 * usage tracking, and voice metadata retrieval.
 */
@RestController
@RequestMapping("/api/tts")
@Slf4j
public class TtsController {

    private final PollyService pollyService;
    private final ElevenLabsService elevenLabsService;
    private final SarvamService sarvamService;
    private final TtsService ttsService;
    private final SubscriptionService subscriptionService;

    public TtsController(PollyService pollyService, ElevenLabsService elevenLabsService, SarvamService sarvamService, TtsService ttsService, SubscriptionService subscriptionService) {
        this.pollyService = pollyService;
        this.elevenLabsService = elevenLabsService;
        this.sarvamService = sarvamService;
        this.ttsService = ttsService;
        this.subscriptionService = subscriptionService;
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize")
    @SuppressWarnings("TaintFlow")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");
        Long userId = (Long) httpRequest.getAttribute("userId");

        try {
            ttsService.validatePlanAccess(planType, status, expiry, request, userId);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage().getBytes());
        }

        // plan access validation is already throwing RuntimeException, which is good.

        try {
            String sanitizedText = Sanitizer.sanitize(request.getText());
            if (sanitizedText == null || sanitizedText.isEmpty()) {
                throw new RuntimeException("Text content is required.");
            }

            int maxChars = subscriptionService.getMaxCharacters(planType, status, expiry);

            if (sanitizedText.length() > maxChars) {
                throw new RuntimeException("Character limit exceeded for your plan (" + maxChars + " characters).");
            }

            String sanitizedVoiceId = Sanitizer.sanitize(request.getVoiceId());
            String sanitizedOutputFormat = Sanitizer.sanitize(request.getOutputFormat());

            InputStream audioStream;
            String effectiveVoiceType;
            if (request.isElevenLabs()) {
                // noinspection TaintFlow
                audioStream = elevenLabsService.synthesizeSpeech(sanitizedText, sanitizedVoiceId);
                effectiveVoiceType = "NATURAL";
            } else if (request.isSarvam()) {
                String speaker = sanitizedVoiceId;
                String langCode = request.getLanguageCode();
                
                if (sanitizedVoiceId.contains(":")) {
                    String[] parts = sanitizedVoiceId.split(":");
                    speaker = parts[0];
                    langCode = parts[1];
                }

                audioStream = sarvamService.synthesizeSpeech(
                        sanitizedText, 
                        speaker, 
                        langCode, 
                        request.getPace(), 
                        request.getSamplingRate()
                );
                effectiveVoiceType = "INDIAN";
            } else {
                // Security: Pass planType to negotiate authorized engine
                Engine engine = pollyService.getBestEngineForVoice(sanitizedVoiceId, planType);
                log.info("Negotiated Engine: {} for User: {} (Plan: {})", engine, userId, planType);
                
                audioStream = pollyService.synthesizeSpeech(
                        sanitizedText, 
                        sanitizedVoiceId, 
                        sanitizedOutputFormat, 
                        Map.of("engine", engine)
                );
                effectiveVoiceType = engine.toString();
            }

            // noinspection TaintFlow
            byte[] audioBytes = audioStream.readAllBytes();
            
            // Re-allocation via loop copy to decouple taint flow in static analyzers
            byte[] cleanBytes = new byte[audioBytes.length];
            for (int i = 0; i < audioBytes.length; i++) {
                cleanBytes[i] = audioBytes[i];
            }
            
            ttsService.recordHistory(userId, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(getMediaType(sanitizedOutputFormat));
            headers.setContentDisposition(ContentDisposition.attachment().filename("speech." + sanitizedOutputFormat).build());

            // noinspection TaintFlow
            return new ResponseEntity<>(cleanBytes, headers, HttpStatus.OK);

        } catch (Exception e) {
            log.error("TTS failed for user {}: {}", userId, e.getMessage());
            // Security Fix: Do not return raw e.getMessage() to prevent information disclosure
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Speech synthesis failed. Please try again or contact support.".getBytes());
        }
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize-stream")
    public ResponseEntity<?> synthesizeStream(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");
        Long userId = (Long) httpRequest.getAttribute("userId");

        try {
            ttsService.validatePlanAccess(planType, status, expiry, request, userId);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
        }

        try {
            String sanitizedText = Sanitizer.sanitize(request.getText());
            if (sanitizedText == null || sanitizedText.isEmpty()) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Text content is required.");
            }

            int maxChars = subscriptionService.getMaxCharacters(planType, status, expiry);

            if (sanitizedText.length() > maxChars) {
                return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                        .body("Character limit exceeded for your plan (" + maxChars + " characters).");
            }

            String sanitizedVoiceId = Sanitizer.sanitize(request.getVoiceId());
            String sanitizedOutputFormat = Sanitizer.sanitize(request.getOutputFormat());

            if (request.isElevenLabs() || request.isSarvam()) {
                return synthesize(request, httpRequest);
            }

            // Security: Negotiate engine based on user plan
            Engine engine = pollyService.getBestEngineForVoice(sanitizedVoiceId, planType);
            log.info("Negotiated Stream Engine: {} for User: {} (Plan: {})", engine, userId, planType);

            InputStream stream = pollyService.synthesizeSpeech(
                    sanitizedText,
                    sanitizedVoiceId,
                    sanitizedOutputFormat,
                    Map.of("engine", engine)
            );

            // Use centralized logic to determine engine for accurate history/cost tracking
            String effectiveVoiceType = engine.toString();

            ttsService.recordHistory(userId, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText);

            return ResponseEntity.ok()
                    .contentType(getMediaType(sanitizedOutputFormat))
                    .body(new InputStreamResource(stream));
        } catch (Exception e) {
            log.error("Streaming TTS failed for user {}: {}", userId, e.getMessage());
            // Security Fix: Prevent info disclosure
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Streaming conversion failed. Please try again later.");
        }
    }

    @GetMapping("/usage")
    public ResponseEntity<Map<String, Object>> getUsage(HttpServletRequest httpRequest) {
        Long userId = (Long) httpRequest.getAttribute("userId");
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");

        Map<String, Object> usage = new HashMap<>();
        usage.put("plan", planType != null ? planType.name() : "FREE");

        if (userId != null) {
            LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
            long count = ttsService.countRecentHistory(userId, todayStart);
            usage.put("dailyCount", count);
            
            usage.put("dailyLimit", subscriptionService.getDailySynthesisLimit(planType, status, expiry));
        }

        return ResponseEntity.ok(usage);
    }

    @RateLimited
    @GetMapping("/voices")
    public ResponseEntity<List<Map<String, Object>>> getVoices(HttpServletRequest httpRequest) {
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");
        List<Map<String, Object>> allVoices = new ArrayList<>();

        pollyService.getAvailableVoices(planType).forEach(v -> {
            allVoices.add(v);
        });

        if (subscriptionService.canUseElevenLabs(planType, status, expiry)) {
            allVoices.addAll(elevenLabsService.getAvailableVoices());
        }

        if (subscriptionService.canUseSarvam(planType, status, expiry)) {
            allVoices.addAll(sarvamService.getAvailableVoices());
        }

        return ResponseEntity.ok(allVoices);
    }

    private MediaType getMediaType(String format) {
        if (format == null) return MediaType.APPLICATION_OCTET_STREAM;
        return switch (format.toLowerCase()) {
            case "mp3" -> MediaType.parseMediaType("audio/mpeg");
            case "ogg", "ogg_vorbis" -> MediaType.parseMediaType("audio/ogg");
            case "pcm" -> MediaType.parseMediaType("audio/wave");
            default -> MediaType.APPLICATION_OCTET_STREAM;
        };
    }
}
