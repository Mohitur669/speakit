package com.speakit.billing.service;

import com.speakit.parameter.service.SystemParameterService;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.entity.PaymentStatus;
import com.speakit.billing.entity.Payment;
import com.speakit.billing.entity.Subscription;
import com.speakit.user.entity.User;

import com.razorpay.RazorpayClient;
import com.razorpay.RazorpayException;
import com.speakit.billing.config.RazorpayConfig;
import com.speakit.billing.dto.PaymentOrderRequest;
import com.speakit.billing.dto.PaymentOrderResponse;
import com.speakit.billing.dto.PaymentVerificationRequest;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.repository.SubscriptionRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.json.JSONObject;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

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
                request.getAmount());

        int amountInPaise = planPrice.multiply(new BigDecimal("100")).intValue();

        // Retrieve subscription Plan ID from system parameters
        String planId = systemParameterService.getParameter(
                request.getPlanType().toUpperCase() + "_PLAN_ID_RAZORPAY",
                "");
        
        String subscriptionId;
        boolean isMockSandbox = (planId == null || planId.trim().isEmpty() || "rzp_test_placeholder".equals(razorpayConfig.getKeyId()));
        if (isMockSandbox) {
            subscriptionId = "sub_sim_" + java.util.UUID.randomUUID().toString().replace("-", "").substring(0, 14);
            log.info("Razorpay credentials/plan not fully configured in environment; creating sandbox subscription {} for user {}", subscriptionId, user.getUsername());
        } else {
            JSONObject subscriptionRequest = new JSONObject();
            subscriptionRequest.put("plan_id", planId);

            // Default to a high cycle count (e.g. 60 cycles = 5 years of monthly billing)
            int billingCycles = systemParameterService.getIntParameter("RAZORPAY_SUBSCRIPTION_BILLING_CYCLES", 60);
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
            subscriptionId = razorpaySubscription.get("id");
        }

        PlanType requestedPlan = PlanType.valueOf(request.getPlanType().toUpperCase());

        // FIX: Each checkout order creates a dedicated Subscription intent for this specific plan and gateway ID.
        // Never mutate or overwrite previous pending subscriptions, ensuring historical payment audits remain intact.
        Subscription subscription = Subscription.builder()
                .user(user)
                .planType(requestedPlan)
                .status(SubscriptionStatus.PAYMENT_PENDING)
                .razorpaySubscriptionId(subscriptionId)
                .build();
        subscriptionRepository.save(subscription);

        // Save a Payment record to track this billing attempt with immutable planType
        Payment payment = Payment.builder()
                .user(user)
                .subscription(subscription)
                .planType(requestedPlan)
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
            String subOrOrderId = (request.getRazorpaySubscriptionId() != null && !request.getRazorpaySubscriptionId().isBlank())
                    ? request.getRazorpaySubscriptionId().trim()
                    : (request.getRazorpayOrderId() != null ? request.getRazorpayOrderId().trim() : null);

            boolean isValid = false;
            if (subOrOrderId != null && subOrOrderId.startsWith("sub_sim_")) {
                isValid = true;
            } else if (subOrOrderId != null && request.getRazorpayPaymentId() != null && request.getRazorpaySignature() != null) {
                String secret = razorpayConfig.getKeySecret();
                String paymentId = request.getRazorpayPaymentId().trim();
                String signature = request.getRazorpaySignature().trim();
                
                // 1. Try official Razorpay SDK Subscription verification
                try {
                    JSONObject subOptions = new JSONObject();
                    subOptions.put("razorpay_subscription_id", subOrOrderId);
                    subOptions.put("razorpay_payment_id", paymentId);
                    subOptions.put("razorpay_signature", signature);
                    if (com.razorpay.Utils.verifySubscription(subOptions, secret)) {
                        isValid = true;
                    }
                } catch (Exception e) {
                    log.debug("SDK verifySubscription check failed: {}", e.getMessage());
                }

                // 2. Try official Razorpay SDK Order verification (in case gateway returns order_id context)
                if (!isValid) {
                    try {
                        JSONObject orderOptions = new JSONObject();
                        orderOptions.put("razorpay_order_id", subOrOrderId);
                        orderOptions.put("razorpay_payment_id", paymentId);
                        orderOptions.put("razorpay_signature", signature);
                        if (com.razorpay.Utils.verifyPaymentSignature(orderOptions, secret)) {
                            isValid = true;
                        }
                    } catch (Exception e) {
                        log.debug("SDK verifyPaymentSignature check failed: {}", e.getMessage());
                    }
                }

                // 3. Fallback: Constant-time direct HMAC comparison for both signature permutations
                if (!isValid) {
                    isValid = verifyDirectHmac(paymentId + "|" + subOrOrderId, signature, secret)
                           || verifyDirectHmac(subOrOrderId + "|" + paymentId, signature, secret);
                }
            }

            if (isValid && subOrOrderId != null) {
                Payment payment = paymentRepository.findByRazorpayOrderId(subOrOrderId)
                        .orElseGet(() -> {
                            Subscription sub = subscriptionRepository
                                    .findByRazorpaySubscriptionId(subOrOrderId)
                                    .orElseThrow(() -> new RuntimeException("Subscription record not found"));
                            return paymentRepository
                                    .findByUserIdOrderByCreatedAtDesc(user.getId(),
                                            org.springframework.data.domain.PageRequest.of(0, 1))
                                    .getContent().stream()
                                    .filter(p -> p.getSubscription() != null
                                            && p.getSubscription().getId().equals(sub.getId()))
                                    .findFirst()
                                    .orElseThrow(() -> new RuntimeException("Payment record not found"));
                        });

                // Security Fix: IDOR Check
                // Ensure that the payment record fetched actually belongs to the authenticated user
                if (!payment.getUser().getId().equals(user.getId())) {
                    log.error(
                            "SECURITY ALERT: User {} attempted to verify payment for SubscriptionId {} belonging to User {}",
                            user.getId(), subOrOrderId, payment.getUser().getId());
                    return false;
                }

                if (payment.getStatus() == PaymentStatus.SUCCESS) {
                    log.warn("Idempotency Triggered: Payment already processed for subscription {}", subOrOrderId);
                    return true;
                }

                // 1. Update Payment Record
                payment.setRazorpayPaymentId(request.getRazorpayPaymentId());
                payment.setRazorpaySignature(request.getRazorpaySignature());
                payment.setStatus(PaymentStatus.SUCCESS);
                paymentRepository.save(payment);

                // 2. Cancel previous active subscription on the Razorpay gateway and DB
                cancelPreviousActiveSubscription(user, subOrOrderId);

                // 3. Delegate Plan Change (Safe, Rank-Aware)
                PlanType targetPlan = payment.getPlanType() != null 
                        ? payment.getPlanType() 
                        : (payment.getSubscription() != null ? payment.getSubscription().getPlanType() : PlanType.PRO_PLUS);

                subscriptionManagementService.changePlan(user, targetPlan, subOrOrderId);

                return true;
            }
        } catch (Exception e) {
            log.error("Payment verification failed", e);
        }
        return false;
    }

    private void cancelPreviousActiveSubscription(User user, String newSubscriptionId) {
        try {
            subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE)
                    .ifPresent(oldSub -> {
                        String oldSubId = oldSub.getRazorpaySubscriptionId();
                        if (oldSubId != null && !oldSubId.equals(newSubscriptionId)) {
                            log.info("Upgrading user {} from old subscription {} to new subscription {}",
                                    user.getUsername(), oldSubId, newSubscriptionId);
                            if (!oldSubId.startsWith("sub_sim_")) {
                                try {
                                    JSONObject cancelRequest = new JSONObject();
                                    cancelRequest.put("cancel_at_cycle_end", false); // Cancel immediately to prevent double charges
                                    razorpayClient.subscriptions.cancel(oldSubId, cancelRequest);
                                    log.info("Successfully cancelled old Razorpay subscription {} for user {}", oldSubId,
                                            user.getUsername());
                                } catch (RazorpayException e) {
                                    log.error("Failed to cancel old Razorpay subscription {} for user {}: {}", oldSubId,
                                            user.getUsername(), e.getMessage());
                                }
                            }

                            oldSub.setStatus(SubscriptionStatus.CANCELLED);
                            oldSub.setCancelledAt(java.time.LocalDateTime.now());
                            subscriptionRepository.save(oldSub);
                        }
                    });
        } catch (Exception e) {
            log.error("Error managing old subscription cleanup during upgrade for user {}", user.getUsername(), e);
        }
    }

    private boolean verifyDirectHmac(String data, String signature, String secret) {
        try {
            javax.crypto.Mac sha256HMAC = javax.crypto.Mac.getInstance("HmacSHA256");
            javax.crypto.spec.SecretKeySpec secretKey = new javax.crypto.spec.SecretKeySpec(
                    secret.getBytes(java.nio.charset.StandardCharsets.UTF_8), "HmacSHA256");
            sha256HMAC.init(secretKey);
            byte[] hash = sha256HMAC.doFinal(data.getBytes(java.nio.charset.StandardCharsets.UTF_8));

            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            // SEC-05: Use constant-time comparison to prevent timing-side-channel attacks (CWE-208).
            return java.security.MessageDigest.isEqual(
                    hexString.toString().getBytes(java.nio.charset.StandardCharsets.UTF_8),
                    signature.getBytes(java.nio.charset.StandardCharsets.UTF_8));
        } catch (Exception e) {
            log.error("Direct HMAC verification failed", e);
            return false;
        }
    }

    /**
     * Sweeps stale PENDING payments created more than 30 minutes ago and marks them FAILED,
     * adhering to Razorpay transaction lifecycle and billing standards.
     */
    @org.springframework.scheduling.annotation.Scheduled(fixedRate = 900_000)
    @Transactional
    public void cleanupStalePendingPayments() {
        try {
            java.time.LocalDateTime cutoff = java.time.LocalDateTime.now().minusMinutes(30);
            int updated = paymentRepository.markStalePendingPaymentsAsFailed(cutoff);
            if (updated > 0) {
                log.info("Razorpay housekeeping: Marked {} stale pending payments as FAILED", updated);
            }
        } catch (Exception e) {
            log.error("Error during stale pending payments sweep", e);
        }
    }
}
