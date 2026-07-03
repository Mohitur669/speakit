package com.speakit.tts.controller;

import com.speakit.tts.service.WebhookService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.Collections;
import java.util.Map;

@RestController
@RequestMapping("/api/v1/webhooks")
@RequiredArgsConstructor
@Slf4j
public class WebhookController {

    private final WebhookService webhookService;

    @PostMapping("/razorpay")
    public ResponseEntity<Map<String, String>> handleRazorpayWebhook(
            @RequestBody String payload,
            @RequestHeader("X-Razorpay-Signature") String signature,
            HttpServletRequest request) {
        
        log.info("Received Razorpay Webhook");
        try {
            webhookService.processWebhook(payload, signature);
            return ResponseEntity.ok(Collections.singletonMap("status", "ok"));
        } catch (Exception e) {
            log.error("Webhook processing failed", e);
            // Security Fix: Do not expose internal error details
            return ResponseEntity.status(400).body(Collections.singletonMap("error", "Webhook processing failed. Check internal logs."));
        }
    }
}
