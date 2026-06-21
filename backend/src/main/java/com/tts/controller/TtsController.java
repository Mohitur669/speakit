package com.tts.controller;

import com.tts.aspect.RateLimitAction;
import com.tts.aspect.RateLimited;
import com.tts.dto.TtsRequest;
import com.tts.entity.PlanType;
import com.tts.entity.SubscriptionStatus;
import com.tts.entity.TtsHistory;
import com.tts.repository.TtsHistoryRepository;
import com.tts.repository.UserRepository;
import com.tts.service.ElevenLabsService;
import com.tts.service.PollyService;
import com.tts.service.SarvamService;
import com.tts.service.SubscriptionService;
import com.tts.util.Sanitizer;
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
    private final UserRepository userRepository;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final SubscriptionService subscriptionService;

    public TtsController(PollyService pollyService, ElevenLabsService elevenLabsService, SarvamService sarvamService, UserRepository userRepository, TtsHistoryRepository ttsHistoryRepository, SubscriptionService subscriptionService) {
        this.pollyService = pollyService;
        this.elevenLabsService = elevenLabsService;
        this.sarvamService = sarvamService;
        this.userRepository = userRepository;
        this.ttsHistoryRepository = ttsHistoryRepository;
        this.subscriptionService = subscriptionService;
    }

    private void recordHistory(HttpServletRequest httpRequest, String voiceId, String voiceName, String voiceType, String format, int charCount, String text) {
        try {
            Long userId = (Long) httpRequest.getAttribute("userId");
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

    private void validatePlanAccess(PlanType planType, SubscriptionStatus status, LocalDateTime expiry, TtsRequest request, HttpServletRequest httpRequest) {
        if (request.isElevenLabs() && !subscriptionService.canUseElevenLabs(planType, status, expiry)) {
            throw new RuntimeException("ElevenLabs AI voices require a Pro Plus subscription.");
        }

        if (request.isSarvam() && !subscriptionService.canUseSarvam(planType, status, expiry)) {
            throw new RuntimeException("Sarvam AI Indian voices require a PRO subscription.");
        }

        Long userId = (Long) httpRequest.getAttribute("userId");
        subscriptionService.validateSynthesisLimit(userId, planType, status, expiry);
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");
        Long userId = (Long) httpRequest.getAttribute("userId");

        try {
            validatePlanAccess(planType, status, expiry, request, httpRequest);
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

            byte[] audioBytes = audioStream.readAllBytes();
            recordHistory(httpRequest, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(getMediaType(sanitizedOutputFormat));
            headers.setContentDisposition(ContentDisposition.attachment().filename("speech." + sanitizedOutputFormat).build());

            return new ResponseEntity<>(audioBytes, headers, HttpStatus.OK);

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
            validatePlanAccess(planType, status, expiry, request, httpRequest);
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

            recordHistory(httpRequest, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText);

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
            long count = ttsHistoryRepository.countRecentByUserId(userId, todayStart);
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
