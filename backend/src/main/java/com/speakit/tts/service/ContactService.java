package com.speakit.tts.service;

import com.speakit.tts.dto.ContactRequest;
import com.speakit.tts.entity.ContactSubmission;
import com.speakit.tts.repository.ContactSubmissionRepository;
import com.shared.util.Sanitizer;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;

@Service
@RequiredArgsConstructor
@Slf4j
public class ContactService {

    private final ContactSubmissionRepository contactRepository;
    private final TelegramService telegramService;
    
    // Memory-efficient deduplication cache (Hashed Content -> Timestamp)
    private final ConcurrentHashMap<String, Long> messageFingerprints = new ConcurrentHashMap<>();
    private static final long DEDUPLICATION_WINDOW_MS = 60000; // 1 minute

    @Transactional
    public void handleSubmission(ContactRequest request, String ipAddress, String requestId) {
        // 1. Bot Detection: Check honeypot field
        if (request.getWebsite() != null && !request.getWebsite().isEmpty()) {
            log.warn("Bot submission detected from IP: {} (Honeypot filled)", ipAddress);
            return; // Silently reject
        }

        // 2. Sanitize and Normalize
        String cleanFirstName = Sanitizer.sanitize(request.getFirstName());
        String cleanLastName = Sanitizer.sanitize(request.getLastName());
        String cleanEmail = Sanitizer.sanitize(request.getEmail().toLowerCase().trim());
        String cleanTopic = Sanitizer.sanitize(request.getTopic());
        String cleanMessage = Sanitizer.sanitize(request.getMessage());

        // 3. Message Fingerprinting (Anti-Spam - Atomic)
        String fingerprint = generateFingerprint(cleanEmail, cleanMessage);
        long now = System.currentTimeMillis();
        Long previousTime = messageFingerprints.putIfAbsent(fingerprint, now);
        
        if (previousTime != null && (now - previousTime < DEDUPLICATION_WINDOW_MS)) {
            log.warn("Duplicate message detected from {}. Blocking to prevent spam.", cleanEmail);
            return;
        }
        
        // Update timestamp if it was a valid new message (Optional refresh)
        messageFingerprints.put(fingerprint, now);

        // 4. Map to Entity & Persist
        ContactSubmission submission = ContactSubmission.builder()
                .firstName(cleanFirstName)
                .lastName(cleanLastName)
                .email(cleanEmail)
                .topic(getTopicLabel(cleanTopic))
                .message(cleanMessage)
                .ipAddress(hashIp(ipAddress)) // Security: Store hashed IP only
                .build();

        contactRepository.save(submission);
        
        // 5. Telegram Notification
        telegramService.sendNotification(
            cleanFirstName + " " + cleanLastName,
            cleanEmail,
            submission.getTopic(),
            cleanMessage,
            requestId
        );

        log.info("Contact submission processed. RequestId: {}", requestId);
        
        // Cleanup cache occasionally (Simplified)
        if (messageFingerprints.size() > 1000) messageFingerprints.clear();
    }

    private String getTopicLabel(String topic) {
        if (topic == null) return "Unknown";
        return switch (topic.toLowerCase()) {
            case "support" -> "Technical Support";
            case "billing" -> "Billing";
            case "enterprise" -> "Enterprise Sales";
            case "feedback" -> "Product Feedback";
            default -> topic.substring(0, 1).toUpperCase() + topic.substring(1);
        };
    }

    private String generateFingerprint(String email, String message) {
        return hashString(email + "|" + message);
    }

    private String hashIp(String ip) {
        return hashString(ip).substring(0, 16);
    }

    private String hashString(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            return String.valueOf(input.hashCode());
        }
    }
}
