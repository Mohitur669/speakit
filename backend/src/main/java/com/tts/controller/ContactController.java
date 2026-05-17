package com.tts.controller;

import com.tts.aspect.RateLimited;
import com.tts.dto.ContactRequest;
import com.tts.util.Sanitizer;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Map;

import com.tts.aspect.RateLimitAction;

@RestController
@RequestMapping("/api/contact")
@Slf4j
public class ContactController {

    @RateLimited(action = RateLimitAction.PUBLIC)
    @PostMapping
    public ResponseEntity<?> submitContactForm(@Valid @RequestBody ContactRequest request) {
        // Sanitize inputs
        String firstName = Sanitizer.sanitize(request.getFirstName());
        String lastName = Sanitizer.sanitize(request.getLastName());
        String email = Sanitizer.sanitize(request.getEmail());
        String topic = Sanitizer.sanitize(request.getTopic());
        String message = Sanitizer.sanitize(request.getMessage());

        // In a real production app, this would integrate with AWS SES, SendGrid, or a CRM like Salesforce/Zendesk.
        // For now, we log it securely and return success to the frontend.
        log.info("Contact form submitted by: {} {} ({}), Topic: {}", firstName, lastName, email, topic);
        log.debug("Message content: {}", message);

        return ResponseEntity.ok(Map.of("message", "Contact request received successfully"));
    }
}