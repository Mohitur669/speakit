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
import java.time.LocalDateTime;
import java.util.UUID;

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

        Payment payment = Payment.builder()
                .user(user)
                .razorpayOrderId(orderId)
                .amount(planPrice)
                .currency(request.getCurrency())
                .status(PaymentStatus.INITIATED)
                .build();
        
        // Handle Plan metadata if needed
        PlanType planType = PlanType.valueOf(request.getPlanType().toUpperCase());
        
        paymentRepository.save(payment);

        return PaymentOrderResponse.builder()
                .orderId(orderId)
                .currency(request.getCurrency())
                .amount(amountInPaise)
                .keyId(razorpayConfig.getKeyId())
                .build();
    }

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

                payment.setRazorpayPaymentId(request.getRazorpayPaymentId());
                payment.setRazorpaySignature(request.getRazorpaySignature());
                payment.setStatus(PaymentStatus.SUCCESS);
                paymentRepository.save(payment);

                activateSubscription(user, payment);
                return true;
            }
        } catch (Exception e) {
            log.error("Payment verification failed", e);
        }
        return false;
    }

    private void activateSubscription(User user, Payment payment) {
        // Simple logic: If it's a success, upgrade user
        // In a real app, you'd check the plan type from the order metadata or DTO
        user.setHasNaturalVoiceAccess(true);
        userRepository.save(user);

        Subscription subscription = Subscription.builder()
                .user(user)
                .planType(PlanType.PRO) // Defaulting to PRO for now, should be dynamic
                .status(SubscriptionStatus.ACTIVE)
                .currentPeriodStart(LocalDateTime.now())
                .currentPeriodEnd(LocalDateTime.now().plusMonths(1))
                .build();
        
        subscriptionRepository.save(subscription);
        payment.setSubscription(subscription);
        paymentRepository.save(payment);
        
        log.info("Subscription activated for user: {}", user.getUsername());
    }
}
