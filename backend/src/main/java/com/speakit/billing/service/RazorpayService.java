package com.speakit.billing.service;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.entity.PaymentStatus;
import com.speakit.billing.entity.Payment;
import com.speakit.billing.entity.Subscription;
import com.speakit.user.entity.User;

import com.razorpay.Order;
import com.razorpay.RazorpayClient;
import com.razorpay.RazorpayException;
import com.razorpay.Utils;
import com.speakit.billing.config.RazorpayConfig;
import com.speakit.billing.dto.PaymentOrderRequest;
import com.speakit.billing.dto.PaymentOrderResponse;
import com.speakit.billing.dto.PaymentVerificationRequest;
import com.speakit.tts.entity.*;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.repository.SubscriptionRepository;
import com.speakit.user.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.UUID;

/**
 * Service handling Razorpay payment orchestration.
 * Integrates with SubscriptionManagementService for lifecycle changes.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class RazorpayService {

    private final RazorpayClient razorpayClient;
    private final RazorpayConfig razorpayConfig;
    private final PaymentRepository paymentRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final UserRepository userRepository;
    private final SystemParameterService systemParameterService;
    private final SubscriptionManagementService subscriptionManagementService;

    /**
     * Creates a Razorpay subscription and an internal PENDING subscription.
     * Idempotency is handled by subscription creation tracking.
     */
    @Transactional
    public PaymentOrderResponse createOrder(PaymentOrderRequest request, User user) throws RazorpayException {
        // Fetch LIVE price from system parameters to ensure accuracy
        BigDecimal planPrice = systemParameterService.getLivePrice(
                request.getPlanType().toUpperCase() + "_PLAN_PRICE_INR", 
                request.getAmount()
        );

        int amountInPaise = planPrice.multiply(new BigDecimal("100")).intValue();

        // Retrieve subscription Plan ID from system parameters
        String planId = systemParameterService.getLiveParameter(
                request.getPlanType().toUpperCase() + "_PLAN_ID_RAZORPAY", 
                ""
        );
        if (planId == null || planId.trim().isEmpty()) {
            throw new RuntimeException("Razorpay Plan ID not configured for plan: " + request.getPlanType() + 
                ". Please configure " + request.getPlanType().toUpperCase() + "_PLAN_ID_RAZORPAY in system parameters.");
        }

        JSONObject subscriptionRequest = new JSONObject();
        subscriptionRequest.put("plan_id", planId);
        
        // Default to a high cycle count (e.g. 60 cycles = 5 years of monthly billing)
        int billingCycles = Integer.parseInt(systemParameterService.getLiveParameter("RAZORPAY_SUBSCRIPTION_BILLING_CYCLES", "60"));
        subscriptionRequest.put("total_count", billingCycles);
        subscriptionRequest.put("quantity", 1);
        subscriptionRequest.put("customer_notify", 1);

        // Attach custom notes for auditing/tracing
        JSONObject notes = new JSONObject();
        notes.put("user_id", user.getId().toString());
        notes.put("plan_type", request.getPlanType().toUpperCase());
        subscriptionRequest.put("notes", notes);

        // Create subscription in Razorpay
        com.razorpay.Subscription razorpaySubscription = razorpayClient.subscriptions.create(subscriptionRequest);
        String subscriptionId = razorpaySubscription.get("id");

        Subscription subscription = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.PAYMENT_PENDING)
                .orElse(Subscription.builder()
                        .user(user)
                        .status(SubscriptionStatus.PAYMENT_PENDING)
                        .build());
        
        subscription.setPlanType(PlanType.valueOf(request.getPlanType().toUpperCase()));
        subscription.setRazorpaySubscriptionId(subscriptionId);
        subscriptionRepository.save(subscription);

        // Save a Payment record to track this billing attempt
        // We store the subscriptionId in razorpayOrderId to satisfy the UNIQUE NOT NULL DB constraint
        Payment payment = Payment.builder()
                .user(user)
                .subscription(subscription)
                .razorpayOrderId(subscriptionId)
                .amount(planPrice)
                .currency(request.getCurrency())
                .status(PaymentStatus.PENDING)
                .build();
        
        paymentRepository.save(payment);

        return PaymentOrderResponse.builder()
                .orderId(subscriptionId) // Kept for backward compatibility
                .subscriptionId(subscriptionId)
                .currency(request.getCurrency())
                .amount(amountInPaise)
                .keyId(razorpayConfig.getKeyId())
                .build();
    }

    /**
     * Verifies the Razorpay subscription signature and activates the subscription.
     * Ensures idempotency to prevent double-upgrades.
     */
    @Transactional
    public boolean verifyPayment(PaymentVerificationRequest request, User user) {
        try {
            boolean isValid = verifySubscriptionSignature(
                    request.getRazorpaySubscriptionId(),
                    request.getRazorpayPaymentId(),
                    request.getRazorpaySignature(),
                    razorpayConfig.getKeySecret()
            );

            if (isValid) {
                Payment payment = paymentRepository.findByRazorpayOrderId(request.getRazorpaySubscriptionId())
                        .orElseGet(() -> {
                            Subscription sub = subscriptionRepository.findByRazorpaySubscriptionId(request.getRazorpaySubscriptionId())
                                    .orElseThrow(() -> new RuntimeException("Subscription record not found"));
                            return paymentRepository.findByUserIdOrderByCreatedAtDesc(user.getId(), org.springframework.data.domain.PageRequest.of(0, 1))
                                    .getContent().stream()
                                    .filter(p -> p.getSubscription() != null && p.getSubscription().getId().equals(sub.getId()))
                                    .findFirst()
                                    .orElseThrow(() -> new RuntimeException("Payment record not found"));
                        });

                // Security Fix: IDOR Check
                // Ensure that the payment record fetched actually belongs to the authenticated user
                if (!payment.getUser().getId().equals(user.getId())) {
                    log.error("SECURITY ALERT: User {} attempted to verify payment for SubscriptionId {} belonging to User {}", 
                            user.getId(), request.getRazorpaySubscriptionId(), payment.getUser().getId());
                    return false;
                }

                if (payment.getStatus() == PaymentStatus.SUCCESS) {
                    log.warn("Idempotency Triggered: Payment already processed for subscription {}", request.getRazorpaySubscriptionId());
                    return true; 
                }

                // 1. Update Payment Record
                payment.setRazorpayPaymentId(request.getRazorpayPaymentId());
                payment.setRazorpaySignature(request.getRazorpaySignature());
                payment.setStatus(PaymentStatus.SUCCESS);
                paymentRepository.save(payment);

                // 2. Delegate Plan Change (Safe, Rank-Aware)
                PlanType targetPlan = payment.getSubscription() != null ? 
                    payment.getSubscription().getPlanType() : PlanType.PRO_PLUS;
                
                subscriptionManagementService.changePlan(user, targetPlan, request.getRazorpaySubscriptionId());
                
                return true;
            }
        } catch (Exception e) {
            log.error("Payment verification failed", e);
        }
        return false;
    }

    private boolean verifySubscriptionSignature(String subscriptionId, String paymentId, String signature, String secret) {
        try {
            String data = paymentId + "|" + subscriptionId;
            javax.crypto.Mac sha256HMAC = javax.crypto.Mac.getInstance("HmacSHA256");
            javax.crypto.spec.SecretKeySpec secretKey = new javax.crypto.spec.SecretKeySpec(secret.getBytes("UTF-8"), "HmacSHA256");
            sha256HMAC.init(secretKey);
            byte[] hash = sha256HMAC.doFinal(data.getBytes("UTF-8"));
            
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString().equals(signature);
        } catch (Exception e) {
            log.error("Subscription signature verification failed manually", e);
            return false;
        }
    }
}
