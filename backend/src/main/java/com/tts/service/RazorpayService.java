package com.tts.service;

import com.razorpay.Order;
import com.razorpay.RazorpayClient;
import com.razorpay.RazorpayException;
import com.razorpay.Utils;
import com.tts.config.RazorpayConfig;
import com.tts.dto.PaymentOrderRequest;
import com.tts.dto.PaymentOrderResponse;
import com.tts.dto.PaymentVerificationRequest;
import com.tts.entity.*;
import com.tts.repository.PaymentRepository;
import com.tts.repository.SubscriptionRepository;
import com.tts.repository.UserRepository;
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
     * Creates a Razorpay order and an internal PENDING subscription.
     * Idempotency is handled by order creation tracking.
     */
    @Transactional
    public PaymentOrderResponse createOrder(PaymentOrderRequest request, User user) throws RazorpayException {
        // Fetch LIVE price from system parameters to ensure accuracy
        BigDecimal planPrice = systemParameterService.getLivePrice(
                request.getPlanType().toUpperCase() + "_PLAN_PRICE_INR", 
                request.getAmount()
        );

        int amountInPaise = planPrice.multiply(new BigDecimal("100")).intValue();

        JSONObject orderRequest = new JSONObject();
        orderRequest.put("amount", amountInPaise);
        orderRequest.put("currency", request.getCurrency());
        orderRequest.put("receipt", "txn_" + UUID.randomUUID().toString().substring(0, 8));

        Order order = razorpayClient.orders.create(orderRequest);
        String orderId = order.get("id");

        // Create subscription record immediately to track plan intent
        Subscription subscription = Subscription.builder()
                .user(user)
                .planType(PlanType.valueOf(request.getPlanType().toUpperCase()))
                .status(SubscriptionStatus.PAYMENT_PENDING)
                .build();
        subscriptionRepository.save(subscription);

        Payment payment = Payment.builder()
                .user(user)
                .subscription(subscription)
                .razorpayOrderId(orderId)
                .amount(planPrice)
                .currency(request.getCurrency())
                .status(PaymentStatus.PENDING)
                .build();
        
        paymentRepository.save(payment);

        return PaymentOrderResponse.builder()
                .orderId(orderId)
                .currency(request.getCurrency())
                .amount(amountInPaise)
                .keyId(razorpayConfig.getKeyId())
                .build();
    }

    /**
     * Verifies the Razorpay signature and activates the subscription.
     * Ensures idempotency to prevent double-upgrades.
     */
    @Transactional
    public boolean verifyPayment(PaymentVerificationRequest request, User user) {
        try {
            JSONObject attributes = new JSONObject();
            attributes.put("razorpay_order_id", request.getRazorpayOrderId());
            attributes.put("razorpay_payment_id", request.getRazorpayPaymentId());
            attributes.put("razorpay_signature", request.getRazorpaySignature());

            boolean isValid = Utils.verifyPaymentSignature(attributes, razorpayConfig.getKeySecret());

            if (isValid) {
                Payment payment = paymentRepository.findByRazorpayOrderId(request.getRazorpayOrderId())
                        .orElseThrow(() -> new RuntimeException("Payment record not found"));

                // Security Fix: IDOR Check
                // Ensure that the payment record fetched actually belongs to the authenticated user
                if (!payment.getUser().getId().equals(user.getId())) {
                    log.error("SECURITY ALERT: User {} attempted to verify payment for OrderId {} belonging to User {}", 
                            user.getId(), request.getRazorpayOrderId(), payment.getUser().getId());
                    return false;
                }

                if (payment.getStatus() == PaymentStatus.SUCCESS) {
                    log.warn("Idempotency Triggered: Payment already processed for order {}", request.getRazorpayOrderId());
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
                
                subscriptionManagementService.changePlan(user, targetPlan, null);
                
                return true;
            }
        } catch (Exception e) {
            log.error("Payment verification failed", e);
        }
        return false;
    }
}
