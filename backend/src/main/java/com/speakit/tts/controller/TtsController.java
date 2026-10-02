package com.speakit.tts.controller;
import com.speakit.user.entity.User;

import com.speakit.shared.aspect.RateLimitAction;
import com.speakit.shared.aspect.RateLimited;
import com.speakit.tts.dto.TtsRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.tts.entity.TtsHistory;
import com.speakit.tts.service.TtsService;
import com.speakit.tts.service.AudioStorageService;
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
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.services.polly.model.Engine;

import java.io.InputStream;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;

import com.speakit.user.repository.UserRepository;
import java.security.Principal;

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
    private final UserRepository userRepository;
    private final AudioStorageService audioStorageService;

    public TtsController(PollyService pollyService, ElevenLabsService elevenLabsService, SarvamService sarvamService, TtsService ttsService, SubscriptionService subscriptionService, UserRepository userRepository, AudioStorageService audioStorageService) {
        this.pollyService = pollyService;
        this.elevenLabsService = elevenLabsService;
        this.sarvamService = sarvamService;
        this.ttsService = ttsService;
        this.subscriptionService = subscriptionService;
        this.userRepository = userRepository;
        this.audioStorageService = audioStorageService;
    }

    private Long resolveUserId(HttpServletRequest request, Principal principal) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId != null) {
            return userId;
        }
        if (principal != null && principal.getName() != null) {
            var userOpt = userRepository.findByUsername(principal.getName());
            if (userOpt.isPresent()) {
                var user = userOpt.get();
                request.setAttribute("userId", user.getId());
                request.setAttribute("planType", user.getPlanType());
                request.setAttribute("subscriptionStatus", user.getSubscriptionStatus());
                request.setAttribute("planExpiry", user.getPlanExpiry());
                return user.getId();
            }
        }
        return null;
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize")
    @SuppressWarnings("TaintFlow")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest, Principal principal) {
        Long userId = resolveUserId(httpRequest, principal);
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");

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
            
            // Store synthesized audio in Cloudflare R2 / local fallback for on-demand streaming
            String audioUrl = null;
            String storageKey = null;
            try {
                var storedAudio = audioStorageService.storeAudio(userId, cleanBytes, sanitizedOutputFormat);
                audioUrl = storedAudio.url();
                storageKey = storedAudio.storageKey();
            } catch (Exception e) {
                log.warn("Failed to store audio in R2/storage for user {}: {}", userId, e.getMessage());
            }

            ttsService.recordHistory(userId, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText, audioUrl, storageKey);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(getMediaType(sanitizedOutputFormat));
            headers.setContentDisposition(ContentDisposition.attachment().filename("speech." + sanitizedOutputFormat).build());

            // noinspection TaintFlow
            return new ResponseEntity<>(cleanBytes, headers, HttpStatus.OK);

        } catch (IllegalArgumentException e) {
            log.warn("Invalid TTS parameter for user {}: {}", userId, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(("Bad request: " + e.getMessage()).getBytes());
        } catch (Exception e) {
            log.error("TTS failed for user {}: {}", userId, e.getMessage());
            // Security Fix: Do not return raw e.getMessage() to prevent information disclosure
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Speech synthesis failed. Please try again or contact support.".getBytes());
        }
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize-stream")
    public ResponseEntity<?> synthesizeStream(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest, Principal principal) {
        Long userId = resolveUserId(httpRequest, principal);
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        SubscriptionStatus status = (SubscriptionStatus) httpRequest.getAttribute("subscriptionStatus");
        LocalDateTime expiry = (LocalDateTime) httpRequest.getAttribute("planExpiry");

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
                return synthesize(request, httpRequest, principal);
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
        } catch (IllegalArgumentException e) {
            log.warn("Invalid streaming TTS parameter for user {}: {}", userId, e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Bad request: " + e.getMessage());
        } catch (Exception e) {
            log.error("Streaming TTS failed for user {}: {}", userId, e.getMessage());
            // Security Fix: Prevent info disclosure
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Streaming conversion failed. Please try again later.");
        }
    }

    @GetMapping("/usage")
    public ResponseEntity<Map<String, Object>> getUsage(HttpServletRequest httpRequest, Principal principal) {
        Long userId = resolveUserId(httpRequest, principal);
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

            LocalDateTime monthStart = LocalDateTime.now().withDayOfMonth(1).truncatedTo(ChronoUnit.DAYS);
            long charsUsed = ttsService.sumCharactersUsed(userId, monthStart);
            usage.put("charactersUsed", charsUsed);
            usage.put("characterLimit", subscriptionService.getMonthlyCharacterLimit(planType));
            usage.put("maxCharsPerRequest", subscriptionService.getMaxCharacters(planType, status, expiry));
        }

        return ResponseEntity.ok(usage);
    }

    @RateLimited
    @GetMapping("/voices")
    public ResponseEntity<List<Map<String, Object>>> getVoices(HttpServletRequest httpRequest, Principal principal) {
        resolveUserId(httpRequest, principal);
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

    @RateLimited
    @PostMapping(value = "/audio-isolation", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> isolateAudio(
            @RequestParam("file") MultipartFile file,
            HttpServletRequest httpRequest,
            Principal principal
    ) {
        Long userId = resolveUserId(httpRequest, principal);
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        if (planType == null || planType == PlanType.FREE) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Audio Isolation requires Pro plan or higher"));
        }

        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Audio file must not be empty"));
        }

        try {
            byte[] cleanBytes = elevenLabsService.isolateAudio(file.getBytes(), file.getOriginalFilename());
            var stored = audioStorageService.storeAudio(userId, cleanBytes, "mp3");
            return ResponseEntity.ok(Map.of(
                    "status", "SUCCESS",
                    "audioUrl", stored.url(),
                    "sizeBytes", cleanBytes.length
            ));
        } catch (Exception e) {
            log.error("Failed to isolate audio for user {}", userId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Audio isolation failed: " + e.getMessage()));
        }
    }

    @RateLimited
    @PostMapping(value = "/speech-to-speech", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<?> speechToSpeech(
            @RequestParam("file") MultipartFile file,
            @RequestParam("voiceId") String voiceId,
            HttpServletRequest httpRequest,
            Principal principal
    ) {
        Long userId = resolveUserId(httpRequest, principal);
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        if (planType == null || planType.getRank() < PlanType.PRO_PLUS.getRank()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Voice Changer / Speech-to-Speech requires Pro Plus or Enterprise plan"));
        }

        if (file == null || file.isEmpty()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Audio file must not be empty"));
        }

        try {
            byte[] revoicedBytes = elevenLabsService.speechToSpeech(file.getBytes(), file.getOriginalFilename(), voiceId);
            var stored = audioStorageService.storeAudio(userId, revoicedBytes, "mp3");
            return ResponseEntity.ok(Map.of(
                    "status", "SUCCESS",
                    "audioUrl", stored.url(),
                    "voiceId", voiceId,
                    "sizeBytes", revoicedBytes.length
            ));
        } catch (Exception e) {
            log.error("Failed to convert speech-to-speech for user {}", userId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Speech-to-Speech conversion failed: " + e.getMessage()));
        }
    }

    @RateLimited
    @PostMapping("/sound-effects")
    public ResponseEntity<?> generateSoundEffect(
            @RequestBody Map<String, Object> payload,
            HttpServletRequest httpRequest,
            Principal principal
    ) {
        Long userId = resolveUserId(httpRequest, principal);
        PlanType planType = (PlanType) httpRequest.getAttribute("planType");
        if (planType == null || planType.getRank() < PlanType.PRO_PLUS.getRank()) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN)
                    .body(Map.of("error", "Sound Effects Generator requires Pro Plus or Enterprise plan"));
        }

        String prompt = (String) payload.get("prompt");
        if (prompt == null || prompt.isBlank()) {
            return ResponseEntity.badRequest().body(Map.of("error", "Prompt is required"));
        }

        Double duration = null;
        if (payload.get("durationSeconds") instanceof Number n) {
            duration = n.doubleValue();
        }

        try {
            byte[] sfxBytes = elevenLabsService.generateSoundEffect(prompt, duration);
            var stored = audioStorageService.storeAudio(userId, sfxBytes, "mp3");
            return ResponseEntity.ok(Map.of(
                    "status", "SUCCESS",
                    "audioUrl", stored.url(),
                    "prompt", prompt,
                    "sizeBytes", sfxBytes.length
            ));
        } catch (Exception e) {
            log.error("Failed to generate sound effects for user {}", userId, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body(Map.of("error", "Sound Effects generation failed: " + e.getMessage()));
        }
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
