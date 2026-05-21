package com.tts.service;

import com.razorpay.Utils;
import com.tts.entity.WebhookEvent;
import com.tts.entity.WebhookEventStatus;
import com.tts.repository.WebhookEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Slf4j
public class WebhookService {

    private final WebhookEventRepository webhookEventRepository;
    
    @Value("${razorpay.webhook.secret}")
    private String webhookSecret;

    @Transactional
    public void processWebhook(String payload, String signature) throws Exception {
        // 1. Verify Signature
        boolean isValid = Utils.verifyWebhookSignature(payload, signature, webhookSecret);
        if (!isValid) {
            log.error("Invalid Webhook Signature");
            throw new Exception("Invalid Signature");
        }

        JSONObject json = new JSONObject(payload);
        String eventId = json.optString("account_id") + "_" + System.currentTimeMillis(); // Simple way to generate unique ID if not present
        
        // Razorpay events usually have an id at top level
        if (json.has("id")) {
            eventId = json.getString("id");
        }

        // 2. Idempotency Check
        if (webhookEventRepository.findByEventId(eventId).isPresent()) {
            log.info("Webhook event {} already processed, skipping", eventId);
            return;
        }

        // 3. Persist Event
        WebhookEvent event = WebhookEvent.builder()
                .eventId(eventId)
                .payload(payload)
                .status(WebhookEventStatus.RECEIVED)
                .build();
        webhookEventRepository.save(event);

        // 4. Handle Event Type
        String eventType = json.getString("event");
        log.info("Processing Razorpay event: {}", eventType);

        try {
            switch (eventType) {
                case "payment.captured":
                    handlePaymentCaptured(json);
                    break;
                case "payment.failed":
                    handlePaymentFailed(json);
                    break;
                // Add more cases like subscription.activated, etc.
                default:
                    log.info("Unhandled event type: {}", eventType);
            }
            event.setStatus(WebhookEventStatus.PROCESSED);
        } catch (Exception e) {
            log.error("Error handling webhook event", e);
            event.setStatus(WebhookEventStatus.FAILED);
        }
        webhookEventRepository.save(event);
    }

    private void handlePaymentCaptured(JSONObject json) {
        JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
        String orderId = paymentEntity.getString("order_id");
        log.info("Payment captured for order: {}", orderId);
        // Business logic to ensure subscription is active if not already done by verification API
    }

    private void handlePaymentFailed(JSONObject json) {
        JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
        String orderId = paymentEntity.getString("order_id");
        log.warn("Payment failed for order: {}", orderId);
        // Handle failure (e.g., notify user, mark payment as failed)
    }
}
