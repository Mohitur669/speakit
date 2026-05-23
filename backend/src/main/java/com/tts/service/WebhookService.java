package com.tts.service;

import com.razorpay.Utils;
import com.tts.entity.*;
import com.tts.repository.PaymentRepository;
import com.tts.repository.SubscriptionRepository;
import com.tts.repository.UserRepository;
import com.tts.repository.WebhookEventRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

@Service
@RequiredArgsConstructor
@Slf4j
public class WebhookService {

    private final WebhookEventRepository webhookEventRepository;
    private final PaymentRepository paymentRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final UserRepository userRepository;
    
    @Value("${razorpay.webhook.secret}")
    private String webhookSecret;

    @Transactional
    public void processWebhook(String payload, String signature) throws Exception {
        JSONObject json = new JSONObject(payload);
        String eventId = json.optString("id", "evt_" + System.currentTimeMillis());

        // 1. Persist Event Immediately (For Audit)
        WebhookEvent event = webhookEventRepository.findByEventId(eventId)
                .orElse(WebhookEvent.builder()
                        .eventId(eventId)
                        .payload(payload)
                        .status(WebhookEventStatus.RECEIVED)
                        .build());
        
        if (event.getId() != null && event.getStatus() == WebhookEventStatus.PROCESSED) {
            log.info("Webhook event {} already processed, skipping", eventId);
            return;
        }
        webhookEventRepository.save(event);

        // 2. Verify Signature
        if (webhookSecret == null || webhookSecret.isBlank()) {
            log.error("Razorpay Webhook Secret is not configured in the application properties!");
        }

        boolean isValid = false;
        try {
            isValid = Utils.verifyWebhookSignature(payload, signature, webhookSecret.trim());
        } catch (Exception e) {
            log.error("Error during signature verification for event: {}", eventId, e);
        }

        if (!isValid) {
            log.error("Invalid Webhook Signature for event: {}. Signature: {}, Secret Length: {}", 
                    eventId, signature, (webhookSecret != null ? webhookSecret.length() : 0));
            event.setStatus(WebhookEventStatus.FAILED);
            webhookEventRepository.save(event);
            throw new Exception("Invalid Signature");
        }

        // 3. Handle Event Type
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
                default:
                    log.info("Unhandled event type: {}", eventType);
            }
            event.setStatus(WebhookEventStatus.PROCESSED);
        } catch (Exception e) {
            log.error("Error handling webhook event: {}", eventId, e);
            event.setStatus(WebhookEventStatus.FAILED);
        }
        webhookEventRepository.save(event);
    }

    private void handleOrderPaid(JSONObject json) {
        JSONObject orderEntity = json.getJSONObject("payload").getJSONObject("order").getJSONObject("entity");
        String orderId = orderEntity.getString("id");
        log.info("Order paid event received for: {}", orderId);
        processSuccessPayment(orderId, null);
    }

    private void handlePaymentCaptured(JSONObject json) {
        JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
        String orderId = paymentEntity.getString("order_id");
        String paymentId = paymentEntity.getString("id");
        log.info("Payment captured event received for order: {}", orderId);
        processSuccessPayment(orderId, paymentId);
    }

    private void processSuccessPayment(String orderId, String paymentId) {
        paymentRepository.findByRazorpayOrderId(orderId).ifPresent(payment -> {
            if (payment.getStatus() != PaymentStatus.SUCCESS) {
                if (paymentId != null) {
                    payment.setRazorpayPaymentId(paymentId);
                }
                payment.setStatus(PaymentStatus.SUCCESS);
                paymentRepository.save(payment);

                User user = payment.getUser();
                Subscription subscription = payment.getSubscription();
                
                String planStr = subscription != null ? subscription.getPlanType().name() : "PRO";
                user.setHasNaturalVoiceAccess(true);
                user.setPlanType(planStr);
                userRepository.save(user);

                if (subscription != null) {
                    subscription.setStatus(SubscriptionStatus.ACTIVE);
                    subscription.setCurrentPeriodStart(LocalDateTime.now());
                    subscription.setCurrentPeriodEnd(LocalDateTime.now().plusMonths(1));
                    subscriptionRepository.save(subscription);
                }
                log.info("Subscription activated via Webhook for user: {} on plan: {}", user.getUsername(), planStr);
            } else {
                log.info("Payment for order {} already marked as SUCCESS", orderId);
            }
        });
    }

    private void handlePaymentFailed(JSONObject json) {
        JSONObject paymentEntity = json.getJSONObject("payload").getJSONObject("payment").getJSONObject("entity");
        String orderId = paymentEntity.getString("order_id");
        log.warn("Payment failed for order: {}", orderId);
        
        paymentRepository.findByRazorpayOrderId(orderId).ifPresent(payment -> {
            payment.setStatus(PaymentStatus.FAILED);
            paymentRepository.save(payment);
            
            if (payment.getSubscription() != null) {
                payment.getSubscription().setStatus(SubscriptionStatus.CANCELLED);
                subscriptionRepository.save(payment.getSubscription());
            }
        });
    }
}
