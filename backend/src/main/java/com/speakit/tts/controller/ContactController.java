package com.speakit.tts.controller;

import com.speakit.tts.aspect.RateLimitAction;
import com.speakit.tts.aspect.RateLimited;
import com.speakit.tts.dto.ContactRequest;
import com.speakit.tts.service.ContactService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

@RestController
@RequestMapping("/api/contact")
@RequiredArgsConstructor
@lombok.extern.slf4j.Slf4j
public class ContactController {

    private final ContactService contactService;

    // Replay Protection Cache (RequestID -> Expiry)
    private final ConcurrentHashMap<String, Long> requestIds = new ConcurrentHashMap<>();
    private static final long REPLAY_WINDOW_MS = 300000; // 5 minutes

    /**
     * Handles public contact form submissions.
     *
     * Security:
     * - Write-Only Sink: POST only.
     * - Defense-in-Depth: Multi-layered rate limiting (IP + Email).
     * - Replay Protection: Validates X-Request-ID header.
     * - Bot Protection: Honeypot field and Fingerprinting.
     */
    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping
    public ResponseEntity<Map<String, String>> submitContact(
            @Valid @RequestBody ContactRequest request,
            @RequestHeader(value = "X-Request-ID", required = false) String headerRequestId,
            HttpServletRequest httpRequest) {
        String requestId = (headerRequestId != null && !headerRequestId.isEmpty())
                ? headerRequestId
                : UUID.randomUUID().toString();

        // 1. Replay Protection (Atomic)
        long now = System.currentTimeMillis();
        Long existingExpiry = requestIds.putIfAbsent(requestId, now + REPLAY_WINDOW_MS);
        if (existingExpiry != null) {
            // Replay detected, return success but don't process (Idempotency)
            log.warn("Replay detected for RequestId: {}. Blocking duplicate execution.", requestId);
            return ResponseEntity.ok(Map.of("message", "Your message has been received."));
        }

        // 2. Process
        String ipAddress = httpRequest.getRemoteAddr();
        contactService.handleSubmission(request, ipAddress, requestId);

        // Cleanup occasionally
        if (requestIds.size() > 5000)
            requestIds.entrySet().removeIf(e -> e.getValue() < now);

        return ResponseEntity.ok(Map.of("message", "Your message has been received."));
    }
}
