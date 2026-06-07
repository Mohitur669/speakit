package com.tts.controller;

import com.tts.aspect.RateLimitAction;
import com.tts.aspect.RateLimited;
import com.tts.dto.TtsRequest;
import com.tts.entity.TtsHistory;
import com.tts.repository.TtsHistoryRepository;
import com.tts.repository.UserRepository;
import com.tts.service.ElevenLabsService;
import com.tts.service.PollyService;
import com.tts.service.SystemParameterService;
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
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Primary REST controller for text-to-speech operations.
 */
@RestController
@RequestMapping("/api/tts")
@Slf4j
public class TtsController {

    private final PollyService pollyService;
    private final ElevenLabsService elevenLabsService;
    private final UserRepository userRepository;
    private final TtsHistoryRepository ttsHistoryRepository;
    private final SystemParameterService systemParameterService;

    public TtsController(PollyService pollyService, ElevenLabsService elevenLabsService, UserRepository userRepository, TtsHistoryRepository ttsHistoryRepository, SystemParameterService systemParameterService) {
        this.pollyService = pollyService;
        this.elevenLabsService = elevenLabsService;
        this.userRepository = userRepository;
        this.ttsHistoryRepository = ttsHistoryRepository;
        this.systemParameterService = systemParameterService;
    }

    private void recordHistory(HttpServletRequest httpRequest, String voiceId, String voiceName, String voiceType, String format, int charCount, String text) {
        try {
            Long userId = (Long) httpRequest.getAttribute("userId");
            if (userId != null) {
                String snippet = text.length() > 50 ? text.substring(0, 47) + "..." : text;
                TtsHistory history = TtsHistory.builder()
                        .user(userRepository.getReferenceById(userId))
                        .voiceId(voiceId)
                        .voiceName(voiceName)
                        .voiceType(voiceType)
                        .outputFormat(format)
                        .characterCount(charCount)
                        .textSnippet(snippet)
                        .build();
                ttsHistoryRepository.save(history);
            }
        } catch (Exception e) {
            log.warn("Failed to record TTS history, proceeding anyway", e);
        }
    }

    private void validatePlanAccess(String planType, TtsRequest request, HttpServletRequest httpRequest) {
        if (request.isElevenLabs()) {
            if (!"PRO_PLUS".equalsIgnoreCase(planType) && !"ENTERPRISE".equalsIgnoreCase(planType)) {
                throw new RuntimeException("ElevenLabs AI voices require a Pro Plus subscription.");
            }
        }

        if ("FREE".equalsIgnoreCase(planType)) {
            Long userId = (Long) httpRequest.getAttribute("userId");
            if (userId != null) {
                LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
                long count = ttsHistoryRepository.countRecentByUserId(userId, todayStart);
                int limit = Integer.parseInt(systemParameterService.getLiveParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "3"));
                if (count >= limit) {
                    throw new RuntimeException("Daily limit of " + limit + " syntheses reached for Free plan. Please upgrade to Pro.");
                }
            }
        }
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        String planType = (String) httpRequest.getAttribute("planType");
        Boolean accessAttr = (Boolean) httpRequest.getAttribute("hasNaturalVoiceAccess");
        boolean hasNaturalAccess = accessAttr != null ? accessAttr : false;

        try {
            validatePlanAccess(planType, request, httpRequest);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage().getBytes());
        }

        String sanitizedText = Sanitizer.sanitize(request.getText());
        if (sanitizedText == null || sanitizedText.isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Text content is required.".getBytes());
        }

        int maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_FREE_CHARACTERS", "200"));
        if ("PRO".equalsIgnoreCase(planType)) maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_CHARACTERS", "5000"));
        else if ("PRO_PLUS".equalsIgnoreCase(planType)) maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_PLUS_CHARACTERS", "20000"));
        else if ("ENTERPRISE".equalsIgnoreCase(planType)) maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_ENTERPRISE_CHARACTERS", "100000"));

        if (sanitizedText.length() > maxChars) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(("Character limit exceeded for your plan (" + maxChars + " characters).").getBytes());
        }

        String sanitizedVoiceId = Sanitizer.sanitize(request.getVoiceId());
        String sanitizedOutputFormat = Sanitizer.sanitize(request.getOutputFormat());

        try {
            InputStream audioStream;
            String effectiveVoiceType;
            if (request.isElevenLabs()) {
                audioStream = elevenLabsService.synthesizeSpeech(sanitizedText, sanitizedVoiceId);
                effectiveVoiceType = "NATURAL";
            } else {
                audioStream = pollyService.synthesizeSpeech(sanitizedText, sanitizedVoiceId, sanitizedOutputFormat, hasNaturalAccess);
                
                // 1. Use user's requested type if valid
                if (request.getVoiceType() != null && !request.getVoiceType().isEmpty()) {
                    effectiveVoiceType = request.getVoiceType().toUpperCase();
                } else {
                    // 2. Fallback to derived type
                    boolean isNeural = pollyService.getAvailableVoices().stream()
                            .filter(v -> v.id().toString().equals(sanitizedVoiceId))
                            .anyMatch(v -> v.supportedEngines().contains(Engine.NEURAL));
                    effectiveVoiceType = (hasNaturalAccess && isNeural) ? "NEURAL" : "STANDARD";
                }
            }

            byte[] audioBytes = audioStream.readAllBytes();
            recordHistory(httpRequest, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(getMediaType(sanitizedOutputFormat));
            headers.setContentDisposition(ContentDisposition.attachment().filename("speech." + sanitizedOutputFormat).build());

            return new ResponseEntity<>(audioBytes, headers, HttpStatus.OK);

        } catch (Exception e) {
            log.error("TTS failed", e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(("TTS failed: " + e.getMessage()).getBytes());
        }
    }

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize-stream")
    public ResponseEntity<?> synthesizeStream(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        String planType = (String) httpRequest.getAttribute("planType");
        Boolean accessAttr = (Boolean) httpRequest.getAttribute("hasNaturalVoiceAccess");
        boolean hasNaturalAccess = accessAttr != null ? accessAttr : false;

        try {
            validatePlanAccess(planType, request, httpRequest);
        } catch (RuntimeException e) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(e.getMessage());
        }

        String sanitizedText = Sanitizer.sanitize(request.getText());
        if (sanitizedText == null || sanitizedText.isEmpty()) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body("Text content is required.");
        }

        int maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_FREE_CHARACTERS", "200"));
        if ("PRO".equalsIgnoreCase(planType)) maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_CHARACTERS", "5000"));
        else if ("PRO_PLUS".equalsIgnoreCase(planType)) maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_PRO_PLUS_CHARACTERS", "20000"));
        else if ("ENTERPRISE".equalsIgnoreCase(planType)) maxChars = Integer.parseInt(systemParameterService.getLiveParameter("MAX_ENTERPRISE_CHARACTERS", "100000"));

        if (sanitizedText.length() > maxChars) {
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Character limit exceeded for your plan (" + maxChars + " characters).");
        }

        String sanitizedVoiceId = Sanitizer.sanitize(request.getVoiceId());
        String sanitizedOutputFormat = Sanitizer.sanitize(request.getOutputFormat());

        if (request.isElevenLabs()) {
            return synthesize(request, httpRequest);
        }

        InputStream stream = pollyService.synthesizeSpeech(
                sanitizedText,
                sanitizedVoiceId,
                sanitizedOutputFormat,
                hasNaturalAccess
        );

        String effectiveVoiceType;
        if (request.getVoiceType() != null && !request.getVoiceType().isEmpty()) {
            effectiveVoiceType = request.getVoiceType().toUpperCase();
        } else {
            boolean isNeural = pollyService.getAvailableVoices().stream()
                    .filter(v -> v.id().toString().equals(sanitizedVoiceId))
                    .anyMatch(v -> v.supportedEngines().contains(Engine.NEURAL));
            effectiveVoiceType = (hasNaturalAccess && isNeural) ? "NEURAL" : "STANDARD";
        }

        recordHistory(httpRequest, sanitizedVoiceId, request.getVoiceName(), effectiveVoiceType, sanitizedOutputFormat, sanitizedText.length(), sanitizedText);

        return ResponseEntity.ok()
                .contentType(getMediaType(sanitizedOutputFormat))
                .body(new InputStreamResource(stream));
    }

    @GetMapping("/usage")
    public ResponseEntity<Map<String, Object>> getUsage(HttpServletRequest httpRequest) {
        Long userId = (Long) httpRequest.getAttribute("userId");
        String planType = (String) httpRequest.getAttribute("planType");

        Map<String, Object> usage = new HashMap<>();
        usage.put("plan", planType);

        if (userId != null) {
            LocalDateTime todayStart = LocalDateTime.now().truncatedTo(ChronoUnit.DAYS);
            long count = ttsHistoryRepository.countRecentByUserId(userId, todayStart);
            usage.put("dailyCount", count);
            
            int limit = -1;
            if ("FREE".equalsIgnoreCase(planType)) {
                limit = Integer.parseInt(systemParameterService.getLiveParameter("FREE_PLAN_SYNTHESIZE_LIMIT", "3"));
            }
            usage.put("dailyLimit", limit);
        }

        return ResponseEntity.ok(usage);
    }
    @RateLimited
    @GetMapping("/voices")
    public ResponseEntity<List<Map<String, Object>>> getVoices(HttpServletRequest httpRequest) {
        String planType = (String) httpRequest.getAttribute("planType");
        List<Map<String, Object>> allVoices = new ArrayList<>();

        pollyService.getAvailableVoices().forEach(v -> {
            Map<String, Object> map = new HashMap<>();
            map.put("id", v.id().toString());
            map.put("name", v.name());
            map.put("gender", v.genderAsString());
            boolean supportsPremium = v.supportedEngines().contains(Engine.NEURAL) ||
                                      v.supportedEngines().stream().anyMatch(e -> e.toString().equalsIgnoreCase("generative") || e.toString().equalsIgnoreCase("long-form"));
            map.put("isNeural", supportsPremium);
            map.put("isStandard", v.supportedEngines().contains(Engine.STANDARD));
            map.put("isElevenLabs", false);
            allVoices.add(map);
        });

        boolean isEligibleForElevenLabs = "PRO_PLUS".equalsIgnoreCase(planType) || "ENTERPRISE".equalsIgnoreCase(planType);
        if (isEligibleForElevenLabs) {
            allVoices.addAll(elevenLabsService.getAvailableVoices());
        }

        return ResponseEntity.ok(allVoices);
    }

    private MediaType getMediaType(String format) {
        if (format == null) return MediaType.APPLICATION_OCTET_STREAM;
        return switch (format.toLowerCase()) {
            case "mp3" -> MediaType.parseMediaType("audio/mpeg");
            case "ogg" -> MediaType.parseMediaType("audio/ogg");
            case "pcm" -> MediaType.parseMediaType("audio/wave");
            default -> MediaType.APPLICATION_OCTET_STREAM;
        };
    }
}
