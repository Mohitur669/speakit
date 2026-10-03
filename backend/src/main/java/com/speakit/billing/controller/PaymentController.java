package com.speakit.billing.controller;
import com.speakit.billing.entity.Payment;

import com.razorpay.RazorpayException;
import com.speakit.billing.dto.AppleVerificationRequest;
import com.speakit.billing.dto.PaymentOrderRequest;
import com.speakit.billing.dto.PaymentOrderResponse;
import com.speakit.billing.dto.PaymentVerificationRequest;
import com.speakit.billing.dto.PaymentHistoryDto;
import com.speakit.billing.dto.ProrationQuoteResponse;
import com.speakit.billing.dto.PlanDowngradeRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.user.entity.User;
import com.speakit.user.service.UserService;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.repository.SubscriptionRepository;
import com.speakit.billing.service.RazorpayService;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import java.time.LocalDateTime;
import java.util.concurrent.CompletableFuture;
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
    private final SubscriptionRepository subscriptionRepository;
    private final SubscriptionManagementService subscriptionManagementService;

    @GetMapping("/proration-quote")
    public ResponseEntity<ProrationQuoteResponse> getProrationQuote(
            @RequestParam String targetPlan,
            @RequestParam(required = false, defaultValue = "INR") String currency,
            HttpServletRequest httpRequest) {

        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        User user = userService.getUserById(userId);
        PlanType plan = PlanType.valueOf(targetPlan.toUpperCase());
        ProrationQuoteResponse quote = subscriptionManagementService.calculateProrationQuote(user, plan, currency);
        return ResponseEntity.ok(quote);
    }

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
        PlanType prevPlan = user.getPlanType();
        subscriptionManagementService.demoteUserToFree(user);
        subscriptionManagementService.recordDowngradeAudit(user, prevPlan, PlanType.FREE, "INTERNAL");
        return ResponseEntity.ok("Downgraded to Free tier successfully");
    }

    @PostMapping("/downgrade")
    public ResponseEntity<String> downgradePlan(
            @RequestParam(required = false) PlanType targetPlan,
            @RequestBody(required = false) PlanDowngradeRequest body,
            HttpServletRequest httpRequest) {
        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        PlanType plan = targetPlan != null ? targetPlan : (body != null ? body.getTargetPlan() : null);
        if (plan == null) {
            return ResponseEntity.badRequest().body("targetPlan is required");
        }
        User user = userService.getUserById(userId);
        PlanType prevPlan = user.getPlanType();
        if (plan == PlanType.FREE) {
            subscriptionManagementService.demoteUserToFree(user);
            subscriptionManagementService.recordDowngradeAudit(user, prevPlan, PlanType.FREE, "INTERNAL");
            return ResponseEntity.ok("Downgraded to Free tier successfully");
        } else if (plan.isLowerThan(prevPlan)) {
            subscriptionManagementService.downgradeUser(user, plan);
            subscriptionManagementService.recordDowngradeAudit(user, prevPlan, plan, "APPLE_STOREKIT");
            return ResponseEntity.ok("Downgraded to " + plan.name() + " successfully");
        } else {
            return ResponseEntity.badRequest().body("Target plan is not a downgrade");
        }
    }

    @PostMapping("/cancel")
    public ResponseEntity<String> cancelSubscription(HttpServletRequest httpRequest) {
        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }
        User user = userService.getUserById(userId);
        subscriptionManagementService.cancelSubscription(user);
        subscriptionManagementService.recordCancellationAudit(user, null);
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

        CompletableFuture.runAsync(() -> {
            try {
                paymentRepository.markStalePendingPaymentsAsFailed(LocalDateTime.now().minusMinutes(30));
            } catch (Exception e) {
                log.debug("Async sweep stale pending payments notice: {}", e.getMessage());
            }
        });

        Page<PaymentHistoryDto> historyPage = paymentRepository
                .findByUserIdOrderByCreatedAtDesc(userId, PageRequest.of(page, size))
                .map(payment -> {
                    com.speakit.billing.entity.PlanType resolvedPlan = payment.getPlanType();
                    if (resolvedPlan == null && payment.getSubscription() != null) {
                        resolvedPlan = payment.getSubscription().getPlanType();
                    }
                    String rawPlan = resolvedPlan != null ? resolvedPlan.name() : "N/A";
                    String normalPlan = switch (rawPlan) {
                        case "PRO" -> "Pro";
                        case "PRO_PLUS" -> "Pro Plus";
                        case "ENTERPRISE" -> "Enterprise";
                        case "FREE" -> "Free";
                        default -> rawPlan;
                    };
                    boolean isApple = "APPLE_STOREKIT".equalsIgnoreCase(payment.getPaymentProvider())
                            || (payment.getRazorpayOrderId() != null && payment.getRazorpayOrderId().startsWith("apple_"));
                    String provider = isApple ? "APPLE_STOREKIT" : (payment.getPaymentProvider() != null ? payment.getPaymentProvider() : "RAZORPAY");
                    String method = isApple ? "In-App Purchase (Apple ID)" : (payment.getPaymentMethod() != null ? payment.getPaymentMethod() : "Razorpay");
                    String txId = isApple
                            ? (payment.getRazorpayPaymentId() != null ? payment.getRazorpayPaymentId() : payment.getRazorpayOrderId().replace("apple_", ""))
                            : (payment.getRazorpayPaymentId() != null ? payment.getRazorpayPaymentId() : payment.getRazorpayOrderId());
                    String note = (payment.getNotes() != null && !payment.getNotes().isBlank())
                            ? payment.getNotes()
                            : (isApple ? "Invoices for App Store purchases are sent to your Apple ID email. You can view your purchase history in your Apple account settings." : null);

                    return PaymentHistoryDto.builder()
                            .id(payment.getId())
                            .planName(normalPlan)
                            .amount(payment.getAmount())
                            .currency(payment.getCurrency())
                            .status(payment.getStatus().name())
                            .razorpayOrderId(payment.getRazorpayOrderId())
                            .paymentProvider(provider)
                            .paymentMethod(method)
                            .transactionId(txId)
                            .invoiceNote(note)
                            .createdAt(payment.getCreatedAt())
                            .build();
                });

        return ResponseEntity.ok(new PagedModel<>(historyPage));
    }

    /**
     * POST /api/v1/payments/apple/verify
     *
     * Called by the iOS app after a successful StoreKit 2 purchase.
     * Maps the Apple productId to the internal PlanType and immediately upgrades
     * the user's plan in the database.
     * Also records an informational transaction in the payments table for Billing History audit.
     *
     * Note: Full Apple JWS receipt verification (App Store Server API) requires a
     * paid Apple Developer account. For StoreKit local/sandbox testing we trust the
     * productId directly. When a paid account is active, add JWS token validation here.
     */
    @PostMapping("/apple/verify")
    public ResponseEntity<String> verifyApplePurchase(
            @RequestBody AppleVerificationRequest request,
            HttpServletRequest httpRequest) {

        Long userId = (Long) httpRequest.getAttribute("userId");
        if (userId == null) {
            return ResponseEntity.status(HttpStatus.UNAUTHORIZED).build();
        }

        // Map StoreKit productId → internal PlanType
        PlanType newPlan = switch (request.getProductId()) {
            case "com.speakit.pro"     -> PlanType.PRO;
            case "com.speakit.proplus" -> PlanType.PRO_PLUS;
            default -> null;
        };

        if (newPlan == null) {
            log.warn("Apple verification: unknown productId '{}' for userId {}", request.getProductId(), userId);
            return ResponseEntity.badRequest().body("Unknown product ID: " + request.getProductId());
        }

        User user = userService.getUserById(userId);
        String currency = (request.getCurrency() != null && !request.getCurrency().isBlank()) ? request.getCurrency() : "INR";
        ProrationQuoteResponse quote = subscriptionManagementService.calculateProrationQuote(user, newPlan, currency);

        // Use the Apple transactionId as the gateway subscription ID for audit trail
        String gatewayRef = "apple_" + request.getTransactionId();
        subscriptionManagementService.upgradeUser(user, newPlan, gatewayRef);

        // Record informational payment history record for Apple StoreKit purchase
        try {
            String baseAppleOrderId = "apple_" + request.getTransactionId();
            String appleOrderId = paymentRepository.findByRazorpayOrderId(baseAppleOrderId).isEmpty()
                    ? baseAppleOrderId
                    : baseAppleOrderId + "_" + System.currentTimeMillis();

            java.math.BigDecimal amount = request.getAmount();
            if (amount == null || amount.compareTo(java.math.BigDecimal.ZERO) <= 0) {
                amount = (quote != null && quote.getAmountToPay() != null)
                        ? quote.getAmountToPay()
                        : (newPlan == PlanType.PRO_PLUS ? java.math.BigDecimal.valueOf(1499.00) : java.math.BigDecimal.valueOf(799.00));
            }

            com.speakit.billing.entity.Subscription activeSub = subscriptionRepository
                    .findFirstByUserAndStatusOrderByIdDesc(user, com.speakit.billing.entity.SubscriptionStatus.ACTIVE)
                    .orElse(null);

            String note = (quote != null && quote.isUpgrade())
                    ? quote.getDescription()
                    : "Apple StoreKit purchase for " + newPlan.name() + " plan. Invoices are sent to your Apple ID email.";

            Payment applePayment = Payment.builder()
                    .user(user)
                    .subscription(activeSub)
                    .planType(newPlan)
                    .razorpayOrderId(appleOrderId)
                    .razorpayPaymentId(request.getTransactionId())
                    .amount(amount)
                    .currency(currency)
                    .paymentProvider("APPLE_STOREKIT")
                    .paymentMethod("In-App Purchase (Apple ID)")
                    .notes(note)
                    .status(com.speakit.billing.entity.PaymentStatus.SUCCESS)
                    .build();

            paymentRepository.save(applePayment);
            log.info("Recorded Apple StoreKit payment in billing history: userId={} txId={} orderId={} amount={} {} note={}",
                    userId, request.getTransactionId(), appleOrderId, amount, currency, note);
        } catch (Exception e) {
            log.error("Failed to record Apple StoreKit payment history for userId={}: {}", userId, e.getMessage(), e);
        }

        log.info("Apple StoreKit purchase verified: userId={} productId={} plan={} transactionId={}",
                userId, request.getProductId(), newPlan, request.getTransactionId());

        return ResponseEntity.ok("Apple purchase verified and plan updated to " + newPlan.name());
    }
}
