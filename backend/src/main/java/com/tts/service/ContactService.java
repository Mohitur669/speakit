package com.tts.service;

import com.tts.dto.ContactRequest;
import com.tts.entity.ContactSubmission;
import com.tts.repository.ContactSubmissionRepository;
import com.tts.util.Sanitizer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class ContactService {

    private final ContactSubmissionRepository contactRepository;

    @Transactional
    public void handleSubmission(ContactRequest request, String ipAddress) {
        // 1. Bot Detection: Check honeypot field
        if (request.getWebsite() != null && !request.getWebsite().isEmpty()) {
            log.warn("Bot submission detected from IP: {} (Honeypot filled)", ipAddress);
            throw new RuntimeException("Request blocked for security reasons.");
        }

        // 2. Sanitize all inputs to prevent XSS and LLM prompt injection
        String cleanFirstName = Sanitizer.sanitize(request.getFirstName());
        String cleanLastName = Sanitizer.sanitize(request.getLastName());
        String cleanEmail = Sanitizer.sanitize(request.getEmail());
        String cleanTopic = Sanitizer.sanitize(request.getTopic());
        String cleanMessage = Sanitizer.sanitize(request.getMessage());

        // 2. Map to Entity
        ContactSubmission submission = ContactSubmission.builder()
                .firstName(cleanFirstName)
                .lastName(cleanLastName)
                .email(cleanEmail)
                .topic(cleanTopic)
                .message(cleanMessage)
                .ipAddress(ipAddress)
                .build();

        // 3. Persist
        contactRepository.save(submission);
        
        log.info("New contact submission received from: {}", cleanEmail);
    }
}
