package com.tts.controller;

import com.tts.aspect.RateLimitAction;
import com.tts.aspect.RateLimited;
import com.tts.dto.ContactRequest;
import com.tts.service.ContactService;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/contact")
@RequiredArgsConstructor
public class ContactController {

    private final ContactService contactService;

    /**
     * Handles public contact form submissions.
     * 
     * Security:
     * - Write-Only: This controller provides no GET, PUT, or DELETE methods.
     * - Defense-in-Depth: Rate limited by IP AND Email to prevent distributed bot attacks
     *   using a single target email or a single IP.
     */
    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping
    public ResponseEntity<Void> submitContact(@Valid @RequestBody ContactRequest request, HttpServletRequest httpRequest) {
        // Use a composite key for rate limiting: IP + Email hash to prevent cross-IP email spam
        // Note: The @RateLimited aspect already handles IP-based limiting. 
        // We handle additional business-level email limiting in the service.
        String ipAddress = httpRequest.getRemoteAddr();
        contactService.handleSubmission(request, ipAddress);
        return ResponseEntity.ok().build();
    }
}
