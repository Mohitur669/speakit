package com.speakit.billing.controller;
import com.speakit.billing.entity.Payment;

import com.razorpay.RazorpayException;
import com.speakit.billing.dto.PaymentOrderRequest;
import com.speakit.billing.dto.PaymentOrderResponse;
import com.speakit.billing.dto.PaymentVerificationRequest;
import com.speakit.billing.dto.PaymentHistoryDto;
import com.speakit.user.entity.User;
import com.speakit.user.service.UserService;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.service.RazorpayService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.data.web.PagedModel;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import com.speakit.billing.service.SubscriptionManagementService;

@RestController
@RequestMapping("/api/v1/payments")
@RequiredArgsConstructor
@Slf4j
public class PaymentController {

    private final RazorpayService razorpayService;
    private final UserService userService;
    private final PaymentRepository paymentRepository;
    private final SubscriptionManagementService subscriptionManagementService;

    @PostMapping("/create-order")
    public ResponseEntity<PaymentOrderResponse> createOrder(
            @RequestBody PaymentOrderRequest request,
            HttpServletRequest httpRequest) throws RazorpayException {
        
        Long userId = (Long) httpRequest.getAttribute("userId");
        User user = userService.getUserById(userId);

        PaymentOrderResponse response = razorpayService.createOrder(request, user);
        return ResponseEntity.ok(response);
    }

    @PostMapping("/verify")
    public ResponseEntity<String> verifyPayment(
            @RequestBody PaymentVerificationRequest request,
            HttpServletRequest httpRequest) {

        Long userId = (Long) httpRequest.getAttribute("userId");
        User user = userService.getUserById(userId);

        boolean isValid = razorpayService.verifyPayment(request, user);
        if (isValid) {
            return ResponseEntity.ok("Payment verified and subscription activated");
        } else {
            return ResponseEntity.badRequest().body("Invalid payment signature");
        }
    }

    @PostMapping("/downgrade-free")
    public ResponseEntity<String> downgradeToFree(HttpServletRequest httpRequest) {
        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        User user = userService.getUserById(userId);
        subscriptionManagementService.demoteUserToFree(user);
        return ResponseEntity.ok("Downgraded to Free tier successfully");
    }

    @PostMapping("/cancel")
    public ResponseEntity<String> cancelSubscription(HttpServletRequest httpRequest) {
        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        User user = userService.getUserById(userId);
        subscriptionManagementService.cancelSubscription(user);
        return ResponseEntity.ok("Subscription scheduled for cancellation at period end");
    }

    @GetMapping("/history")
    public ResponseEntity<PagedModel<PaymentHistoryDto>> getPaymentHistory(
            HttpServletRequest request,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        Long userId = (Long) request.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        Page<PaymentHistoryDto> historyPage = paymentRepository
                .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(page, size))
                .map(payment -> {
                    String rawPlan = payment.getSubscription() != null ? payment.getSubscription().getPlanType().name() : "N/A";
                    String normalPlan = switch (rawPlan) {
                        case "PRO" -> "Pro";
                        case "PRO_PLUS" -> "Pro Plus";
                        case "ENTERPRISE" -> "Enterprise";
                        case "FREE" -> "Free";
                        default -> rawPlan;
                    };
                    return PaymentHistoryDto.builder()
                            .id(payment.getId())
                            .planName(normalPlan)
                            .amount(payment.getAmount())
                            .currency(payment.getCurrency())
                            .status(payment.getStatus().name())
                            .razorpayOrderId(payment.getRazorpayOrderId())
                            .createdAt(payment.getCreatedAt())
                            .build();
                });

        return ResponseEntity.ok(new PagedModel<>(historyPage));
    }
}
