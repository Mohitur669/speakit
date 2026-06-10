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

        // Create subscription record immediately to track plan intent
        Subscription subscription = Subscription.builder()
                .user(user)
                .planType(PlanType.valueOf(request.getPlanType().toUpperCase()))
                .status(SubscriptionStatus.PENDING)
                .build();
        subscriptionRepository.save(subscription);

        Payment payment = Payment.builder()
                .user(user)
                .subscription(subscription)
                .razorpayOrderId(orderId)
                .amount(planPrice)
                .currency(request.getCurrency())
                .status(PaymentStatus.INITIATED)
                .build();
        
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

                if (payment.getStatus() == PaymentStatus.SUCCESS) {
                    log.warn("Replay attempt detected for order: {}", request.getRazorpayOrderId());
                    return true; 
                }

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
        // Upgrade user based on plan
        String planStr = payment.getSubscription() != null ? 
            payment.getSubscription().getPlanType().name() : "PRO_PLUS";
            
        user.setPlanType(planStr);
        userRepository.save(user);

        // Ensure subscription record is consistent and ACTIVE
        Subscription subscription = payment.getSubscription();
        if (subscription == null) {
            subscription = Subscription.builder()
                    .user(user)
                    .planType(PlanType.PRO_PLUS)
                    .status(SubscriptionStatus.ACTIVE)
                    .currentPeriodStart(LocalDateTime.now())
                    .currentPeriodEnd(LocalDateTime.now().plusMonths(1))
                    .build();
            
            subscriptionRepository.save(subscription);
            payment.setSubscription(subscription);
        } else {
            subscription.setStatus(SubscriptionStatus.ACTIVE);
            subscription.setCurrentPeriodStart(LocalDateTime.now());
            subscription.setCurrentPeriodEnd(LocalDateTime.now().plusMonths(1));
            subscriptionRepository.save(subscription);
        }
        
        paymentRepository.save(payment);
        log.info("Subscription ({}) activated for user: {}", planStr, user.getUsername());
    }
}
