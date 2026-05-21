package com.tts.controller;

import com.tts.aspect.RateLimitAction;
import com.tts.aspect.RateLimited;
import com.tts.dto.TtsRequest;
import com.tts.entity.TtsHistory;
import com.tts.repository.TtsHistoryRepository;
import com.tts.repository.UserRepository;
import com.tts.service.PollyService;
import com.tts.util.Sanitizer;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.*;
import org.springframework.web.bind.annotation.*;
import software.amazon.awssdk.services.polly.model.Engine;

import java.io.InputStream;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Primary REST controller for text-to-speech operations.
 * 
 * Handles:
 * - Direct synthesis requests (buffered output)
 * - Streaming synthesis requests (chunked output)
 * - Fetching available voice metadata from AWS Polly
 * - Enforcing plan-based character limits and voice filtering
 * - Asynchronous recording of usage analytics via TtsHistory
 * 
 * Performance Notes:
 * - Uses pre-cached Request Attributes (populated by JwtAuthenticationFilter) 
 *   to eliminate N+1 user queries during the hot-path synthesis flow.
 */
@RestController
@RequestMapping("/api/tts")
@Slf4j
public class TtsController {

    private final PollyService pollyService;
    private final UserRepository userRepository;
    private final TtsHistoryRepository ttsHistoryRepository;

    public TtsController(PollyService pollyService, UserRepository userRepository, TtsHistoryRepository ttsHistoryRepository) {
        this.pollyService = pollyService;
        this.userRepository = userRepository;
        this.ttsHistoryRepository = ttsHistoryRepository;
    }

    /**
     * Records the TTS generation request to the history log for analytics and billing.
     * Uses getReferenceById to avoid an unnecessary SELECT query against the User table.
     */
    private void recordHistory(HttpServletRequest request, String voiceId, String format, int charCount, boolean isNeural, String text) {
        try {
            Long userId = (Long) request.getAttribute("userId");
            if (userId != null) {
                String snippet = text.length() > 50 ? text.substring(0, 47) + "..." : text;
                TtsHistory history = TtsHistory.builder()
                        .user(userRepository.getReferenceById(userId)) // Avoids DB SELECT
                        .voiceId(voiceId)
                        .outputFormat(format)
                        .characterCount(charCount)
                        .isNeural(isNeural)
                        .textSnippet(snippet)
                        .build();
                ttsHistoryRepository.save(history);
            }
        } catch (Exception e) {
            log.warn("Failed to record TTS history, proceeding anyway", e);
        }
    }

    /**
     * Synthesizes text into an audio file payload.
     * Enforces character limits based on the user's subscription tier.
     * 
     * @param request Validated JSON payload containing text and voice preferences
     * @param httpRequest The underlying HTTP request containing pre-cached user context
     * @return Raw audio byte array wrapped in a ResponseEntity
     */
    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize")
    public ResponseEntity<byte[]> synthesize(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        Boolean accessAttr = (Boolean) httpRequest.getAttribute("hasNaturalVoiceAccess");
        boolean hasNaturalAccess = accessAttr != null ? accessAttr : false;

        // Sanitize first, then check length
        String sanitizedText = Sanitizer.sanitize(request.getText());
        if (sanitizedText == null || sanitizedText.isEmpty()) {
            log.warn("Synthesis rejected: Empty content");
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Text content is required after sanitization.".getBytes());
        }
        
        // Enforce plan-based character limits on sanitized text
        int maxChars = hasNaturalAccess ? 3000 : 200;
        if (sanitizedText.length() > maxChars) {
            log.warn("Synthesis rejected: Character limit exceeded. length={}, limit={}", sanitizedText.length(), maxChars);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body(("Character limit exceeded for your plan (" + maxChars + " characters).").getBytes());
        }

        String sanitizedVoiceId = Sanitizer.sanitize(request.getVoiceId());
        String sanitizedOutputFormat = Sanitizer.sanitize(request.getOutputFormat());

        log.info("Starting synthesis: voice={}, format={}, length={}", sanitizedVoiceId, sanitizedOutputFormat, sanitizedText.length());

        try (InputStream audioStream = pollyService.synthesizeSpeech(
                sanitizedText,
                sanitizedVoiceId,
                sanitizedOutputFormat,
                hasNaturalAccess
        )) {

            byte[] audioBytes = audioStream.readAllBytes();
            
            // Record analytics history async-like
            recordHistory(httpRequest, sanitizedVoiceId, sanitizedOutputFormat, sanitizedText.length(), hasNaturalAccess, sanitizedText);
            
            log.info("Synthesis successful: {} bytes generated", audioBytes.length);
            MediaType mediaType = getMediaType(sanitizedOutputFormat);

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(mediaType);
            headers.setContentDisposition(
                    ContentDisposition.attachment()
                            .filename("speech." + sanitizedOutputFormat)
                            .build()
            );

            return new ResponseEntity<>(audioBytes, headers, HttpStatus.OK);

        } catch (Exception e) {
            log.debug("TTS failed for voice={} format={}", sanitizedVoiceId, sanitizedOutputFormat, e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(("TTS failed: " + e.getMessage()).getBytes());
        }
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

    @RateLimited(action = RateLimitAction.TTS)
    @PostMapping("/synthesize-stream")
    public ResponseEntity<?> synthesizeStream(@Valid @RequestBody TtsRequest request, HttpServletRequest httpRequest) {
        Boolean accessAttr = (Boolean) httpRequest.getAttribute("hasNaturalVoiceAccess");
        boolean hasNaturalAccess = accessAttr != null ? accessAttr : false;

        // Sanitize first, then check length
        String sanitizedText = Sanitizer.sanitize(request.getText());
        if (sanitizedText == null || sanitizedText.isEmpty()) {
            log.warn("Streaming synthesis rejected: Empty content");
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Text content is required after sanitization.");
        }
        
        // Enforce plan-based character limits on sanitized text
        int maxChars = hasNaturalAccess ? 3000 : 200;
        if (sanitizedText.length() > maxChars) {
            log.warn("Streaming synthesis rejected: Character limit exceeded. length={}, limit={}", sanitizedText.length(), maxChars);
            return ResponseEntity.status(HttpStatus.BAD_REQUEST)
                    .body("Character limit exceeded for your plan (" + maxChars + " characters).");
        }

        String sanitizedVoiceId = Sanitizer.sanitize(request.getVoiceId());
        String sanitizedOutputFormat = Sanitizer.sanitize(request.getOutputFormat());

        log.info("Starting streaming synthesis: voice={}, format={}, length={}", sanitizedVoiceId, sanitizedOutputFormat, sanitizedText.length());

        InputStream stream = pollyService.synthesizeSpeech(
                sanitizedText,
                sanitizedVoiceId,
                sanitizedOutputFormat,
                hasNaturalAccess
        );

        // Record analytics history async-like
        recordHistory(httpRequest, sanitizedVoiceId, sanitizedOutputFormat, sanitizedText.length(), hasNaturalAccess, sanitizedText);

        log.info("Streaming synthesis initiated successfully");

        return ResponseEntity.ok()
                .contentType(getMediaType(sanitizedOutputFormat))
                .body(new InputStreamResource(stream));
    }

    @RateLimited
    @GetMapping("/voices")
    public ResponseEntity<List<Map<String, Object>>> getVoices(HttpServletRequest httpRequest) {
        List<Map<String, Object>> voices = pollyService.getAvailableVoices()
                .stream()
                .map(v -> {
                    Map<String, Object> map = new HashMap<>();
                    map.put("id", v.id().toString());
                    map.put("name", v.name());
                    map.put("gender", v.genderAsString());
                    
                    // Core Business Rule: Neural tab includes all premium engines (Neural, Generative, Long Form)
                    // This ensures the count reaches the expected 13 for AWS en-US catalog.
                    boolean supportsPremium = v.supportedEngines().contains(Engine.NEURAL) || 
                                              v.supportedEngines().stream().anyMatch(e -> e.toString().equalsIgnoreCase("generative") || e.toString().equalsIgnoreCase("long-form"));
                    
                    map.put("isNeural", supportsPremium);
                    map.put("isStandard", v.supportedEngines().contains(Engine.STANDARD));
                    return map;
                })
                .collect(Collectors.toList());
        return ResponseEntity.ok(voices);
    }
}
