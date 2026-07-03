package com.speakit.tts.service;

import com.razorpay.Utils;
import com.speakit.tts.entity.*;
import com.speakit.tts.repository.PaymentRepository;
import com.speakit.tts.repository.SubscriptionRepository;
import com.speakit.tts.repository.UserRepository;
import com.speakit.tts.repository.WebhookEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Service for handling incoming webhooks from Razorpay.
 * Robust implementation with idempotency and audit tracking.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class WebhookService {

    private final WebhookEventRepository webhookEventRepository;
    private final PaymentRepository paymentRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final UserRepository userRepository;
    private final SubscriptionManagementService subscriptionManagementService;
    
    @Value("${razorpay.webhook.secret:}")
    private String webhookSecret;

    /**
     * Entry point for all Razorpay webhook events.
     * Validates signature and ensures exactly-once processing.
     */
    @Transactional
    public void processWebhook(String payload, String signature) throws Exception {
        JSONObject json = new JSONObject(payload);
        String eventId = json.optString("id", "evt_" + System.currentTimeMillis());

        // 1. Idempotency Check
        WebhookEvent event = webhookEventRepository.findByEventId(eventId)
                .orElse(WebhookEvent.builder()
                        .eventId(eventId)
                        .payload(payload)
                        .status(WebhookEventStatus.RECEIVED)
                        .build());
        
        if (event.getId() != null && event.getStatus() == WebhookEventStatus.PROCESSED) {
            log.info("Duplicate Webhook event {} received, skipping", eventId);
            return;
        }
        webhookEventRepository.save(event);

        // 2. Verify Authenticity
        if (webhookSecret == null || webhookSecret.isBlank()) {
            log.error("CRITICAL: Razorpay Webhook Secret is not configured!");
        }

        boolean isValid = false;
        try {
            isValid = Utils.verifyWebhookSignature(payload, signature, webhookSecret.trim());
        } catch (Exception e) {
            log.error("Signature verification error for event: {}", eventId, e);
        }

        if (!isValid) {
            log.error("Unauthorized Webhook signature for event: {}", eventId);
            event.setStatus(WebhookEventStatus.FAILED);
            webhookEventRepository.save(event);
            throw new Exception("Invalid Signature");
        }

        // 3. Process Event (Transactionally)
        String eventType = json.getString("event");
        log.info("Processing Razorpay event: {}", eventType);

        try {
            switch (eventType) {
                case "order.paid":
                    handleOrderPaid(json);
                    break;
                case "payment.captured":
                    handlePaymentCaptured(json);
                    break;
                case "payment.failed":
                    handlePaymentFailed(json);
                    break;
                case "subscription.cancelled":
                    handleSubscriptionCancelled(json);
                    break;
                default:
                    log.info("Webhook event type ignored: {}", eventType);
            }
            event.setStatus(WebhookEventStatus.PROCESSED);
        } catch (Exception e) {
            log.error("Failed to process webhook event: {}", eventId, e);
            event.setStatus(WebhookEventStatus.FAILED);
        }
        webhookEventRepository.save(event);
    }

    private void handleOrderPaid(JSONObject json) {
        JSONObject orderEntity = json.getJSONObject("payload").getJSONObject("order").getJSONObject("entity");
        String orderId = orderEntity.getString("id");
        processSuccessPayment(orderId, null);
    }

    private void handlePaymentCaptured(JSONObject json) {
        JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
        String orderId = paymentEntity.getString("order_id");
        String paymentId = paymentEntity.getString("id");
        processSuccessPayment(orderId, paymentId);
    }

    /**
     * Atomic activation of subscription from successful payment.
     */
    private void processSuccessPayment(String orderId, String paymentId) {
        paymentRepository.findByRazorpayOrderId(orderId).ifPresent(payment -> {
            if (payment.getStatus() != PaymentStatus.SUCCESS) {
                if (paymentId != null) {
                    payment.setRazorpayPaymentId(paymentId);
                }
                payment.setStatus(PaymentStatus.SUCCESS);
                paymentRepository.save(payment);

                User user = payment.getUser();
                PlanType plan = java.util.Optional.ofNullable(payment.getSubscription())
                        .map(Subscription::getPlanType)
                        .orElse(PlanType.PRO_PLUS);
                
                subscriptionManagementService.changePlan(user, plan, null);
                
                log.info("Webhook: Activated plan ({}) for user {}", plan, user.getUsername());
            }
        });
    }

    private void handlePaymentFailed(JSONObject json) {
        JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
        String orderId = paymentEntity.getString("order_id");
        
        paymentRepository.findByRazorpayOrderId(orderId).ifPresent(payment -> {
            payment.setStatus(PaymentStatus.FAILED);
            paymentRepository.save(payment);
            
            if (payment.getSubscription() != null) {
                payment.getSubscription().setStatus(SubscriptionStatus.PAYMENT_PENDING);
                subscriptionRepository.save(payment.getSubscription());
            }
            log.warn("Webhook: Payment failed for order {}", orderId);
        });
    }

    private void handleSubscriptionCancelled(JSONObject json) {
        JSONObject subEntity = json.getJSONObject("payload").getJSONObject("subscription").getJSONObject("entity");
        String subId = subEntity.getString("id");

        subscriptionRepository.findByRazorpaySubscriptionId(subId).ifPresent(sub -> {
            subscriptionManagementService.cancelSubscription(sub.getUser());
            log.info("Webhook: Subscription {} cancelled remotely", subId);
        });
    }
}
