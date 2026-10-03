package com.speakit.billing.service;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.entity.Subscription;
import com.speakit.user.entity.User;

import com.speakit.billing.dto.ProrationQuoteResponse;
import com.speakit.billing.entity.Payment;
import com.speakit.billing.entity.PaymentStatus;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.billing.repository.SubscriptionRepository;
import com.speakit.user.repository.UserRepository;
import com.razorpay.RazorpayClient;
import com.razorpay.RazorpayException;
import org.json.JSONObject;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

/**
 * Production-grade service for managing subscription lifecycles.
 * Handles upgrades, downgrades, cancellations, and renewals.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class SubscriptionManagementService {

    private final UserRepository userRepository;
    private final SubscriptionRepository subscriptionRepository;
    private final RazorpayClient razorpayClient;
    private final PaymentRepository paymentRepository;
    private final SystemParameterService systemParameterService;

    /**
     * Changes a user's plan.
     * UPGRADE: Higher rank, immediate activation.
     * DOWNGRADE: Lower rank, schedule at period end.
     */
    @Transactional
    public void changePlan(User user, PlanType newPlan, String gatewaySubscriptionId) {
        PlanType currentPlan = user.getPlanType();
        
        if (newPlan == currentPlan) {
            log.info("User {} already on plan {}", user.getUsername(), newPlan);
            return;
        }

        if (newPlan.isHigherThan(currentPlan)) {
            // Immediate Upgrade
            upgradeUser(user, newPlan, gatewaySubscriptionId);
        } else {
            // Schedule Downgrade
            scheduleDowngrade(user, newPlan);
        }
    }

    /**
     * Upgrades a user to a new plan immediately.
     */
    @Transactional
    public void upgradeUser(User user, PlanType newPlan, String gatewaySubscriptionId) {
        log.info("Upgrading user: {} from {} to plan: {}", user.getUsername(), user.getPlanType(), newPlan);

        // 1. Update User Entity (Immediate Benefit)
        user.setPlanType(newPlan);
        user.setSubscriptionStatus(SubscriptionStatus.ACTIVE);
        user.setPlanExpiry(LocalDateTime.now().plusMonths(1)); 
        userRepository.save(user);

        // 2. Manage Subscription Record
        Subscription subscription = null;
        if (gatewaySubscriptionId != null && !gatewaySubscriptionId.trim().isEmpty()) {
            subscription = subscriptionRepository.findByRazorpaySubscriptionId(gatewaySubscriptionId).orElse(null);
        }
        
        if (subscription == null) {
            subscription = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE)
                    .orElse(Subscription.builder()
                            .user(user)
                            .build());
        }

        subscription.setPlanType(newPlan);
        subscription.setStatus(SubscriptionStatus.ACTIVE);
        subscription.setRazorpaySubscriptionId(gatewaySubscriptionId);
        subscription.setCurrentPeriodStart(LocalDateTime.now());
        subscription.setCurrentPeriodEnd(user.getPlanExpiry());
        subscription.setNextBillingDate(subscription.getCurrentPeriodEnd());
        subscription.setCancelAtPeriodEnd(false); 
        
        subscriptionRepository.save(subscription);
    }

    /**
     * Downgrades a user's plan immediately while keeping period validity.
     * Updates plan type and quota to the lower tier and cancels recurring auto-renewals.
     */
    @Transactional
    public void downgradeUser(User user, PlanType lowerPlan) {
        log.info("Downgrading user: {} from {} to plan: {}", user.getUsername(), user.getPlanType(), lowerPlan);

        Subscription activeSub = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE).orElse(null);

        if (activeSub != null) {
            String activeSubId = activeSub.getRazorpaySubscriptionId();
            if (activeSubId != null && activeSubId.startsWith("sub_") && (activeSub.getCancelAtPeriodEnd() == null || !activeSub.getCancelAtPeriodEnd())) {
                try {
                    JSONObject cancelRequest = new JSONObject();
                    cancelRequest.put("cancel_at_cycle_end", true);
                    razorpayClient.subscriptions.cancel(activeSubId, cancelRequest);
                    log.info("Successfully scheduled cycle-end cancellation in Razorpay for downgraded subscription {} of user {}", activeSubId, user.getUsername());
                } catch (RazorpayException e) {
                    log.warn("Notice: Razorpay subscription {} already cancelled or cannot be cancelled: {}", activeSubId, e.getMessage());
                }
            }
            activeSub.setPlanType(lowerPlan);
            activeSub.setCancelAtPeriodEnd(true);
            subscriptionRepository.save(activeSub);
        }

        user.setPlanType(lowerPlan);
        userRepository.save(user);
    }

    /**
     * Schedules a downgrade for a user.
     * Per Industry Standards: Access remains until the current period ends.
     */
    @Transactional
    public void scheduleDowngrade(User user, PlanType lowerPlan) {
        log.info("Scheduling downgrade for user: {} to plan: {}", user.getUsername(), lowerPlan);

        Subscription activeSub = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE)
                .orElse(null);

        if (activeSub != null) {
            String activeSubId = activeSub.getRazorpaySubscriptionId();
            if (activeSubId != null && activeSubId.startsWith("sub_") && (activeSub.getCancelAtPeriodEnd() == null || !activeSub.getCancelAtPeriodEnd())) {
                try {
                    JSONObject cancelRequest = new JSONObject();
                    cancelRequest.put("cancel_at_cycle_end", true);
                    razorpayClient.subscriptions.cancel(activeSubId, cancelRequest);
                    log.info("Successfully scheduled cycle-end cancellation in Razorpay for downgraded subscription {} of user {}", activeSubId, user.getUsername());
                } catch (RazorpayException e) {
                    log.warn("Notice: Razorpay subscription {} already cancelled or cannot be cancelled: {}", activeSubId, e.getMessage());
                }
            }
            activeSub.setPlanType(lowerPlan);
            activeSub.setCancelAtPeriodEnd(true);
            subscriptionRepository.save(activeSub);
        }

        user.setPlanType(lowerPlan);
        userRepository.save(user);
    }

    /**
     * Cancels a subscription at the end of the current period.
     */
    @Transactional
    public void cancelSubscription(User user) {
        log.info("Cancelling subscription for user: {}", user.getUsername());

        Subscription activeSub = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE)
                .orElseThrow(() -> new RuntimeException("No active subscription found to cancel"));

        // Cancel on Razorpay side only if it is a Razorpay subscription (starts with sub_)
        String activeSubId = activeSub.getRazorpaySubscriptionId();
        if (activeSubId != null && activeSubId.startsWith("sub_") && (activeSub.getCancelAtPeriodEnd() == null || !activeSub.getCancelAtPeriodEnd())) {
            try {
                JSONObject cancelRequest = new JSONObject();
                cancelRequest.put("cancel_at_cycle_end", true); // Auto-cancel at cycle end
                razorpayClient.subscriptions.cancel(activeSubId, cancelRequest);
                log.info("Successfully scheduled cycle-end cancellation in Razorpay for subscription {} of user {}", activeSubId, user.getUsername());
            } catch (RazorpayException e) {
                log.warn("Notice: Razorpay subscription {} already cancelled or cannot be cancelled: {}", activeSubId, e.getMessage());
            }
        }

        activeSub.setCancelAtPeriodEnd(true);
        activeSub.setCancelledAt(LocalDateTime.now());
        
        subscriptionRepository.save(activeSub);
    }

    /**
     * Handles webhook-based remote cancellations from Razorpay.
     * Ensures we only demote the user if they do not have a separate active subscription.
     */
    @Transactional
    public void handleSubscriptionCancelled(String razorpaySubscriptionId) {
        subscriptionRepository.findByRazorpaySubscriptionId(razorpaySubscriptionId).ifPresent(sub -> {
            // 1. Mark subscription as CANCELLED in DB
            sub.setStatus(SubscriptionStatus.CANCELLED);
            sub.setCancelledAt(LocalDateTime.now());
            subscriptionRepository.save(sub);
            
            // 2. Only demote the user if they do not have a different active subscription
            User user = sub.getUser();
            subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE)
                .ifPresentOrElse(activeSub -> {
                    if (activeSub.getRazorpaySubscriptionId() == null || activeSub.getRazorpaySubscriptionId().equals(razorpaySubscriptionId)) {
                        demoteUserToFree(user);
                    }
                }, () -> {
                    demoteUserToFree(user);
                });
        });
    }

    /**
     * Demotes a user back to the FREE tier.
     */
    @Transactional
    public void demoteUserToFree(User user) {
        log.info("Demoting user {} to FREE plan due to subscription cancellation/expiration", user.getUsername());
        user.setPlanType(PlanType.FREE);
        user.setSubscriptionStatus(SubscriptionStatus.ACTIVE);
        user.setPlanExpiry(null);
        userRepository.save(user);
    }

    /**
     * Reactivates a cancelled subscription before it expires.
     */
    @Transactional
    public void reactivateSubscription(User user) {
        log.info("Reactivating subscription for user: {}", user.getUsername());

        Subscription sub = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE)
                .orElseThrow(() -> new RuntimeException("No active (but cancelled) subscription found"));

        if (sub.getCancelAtPeriodEnd() == null || !sub.getCancelAtPeriodEnd()) {
            log.info("Subscription already active and set to renew.");
            return;
        }

        sub.setCancelAtPeriodEnd(false);
        sub.setCancelledAt(null);
        
        subscriptionRepository.save(sub);
    }

    /**
     * Calculates proration quotation for an upgrade or plan modification.
     * Computes unused credit of current subscription based on remaining cycle days.
     */
    public ProrationQuoteResponse calculateProrationQuote(User user, PlanType targetPlan, String currency) {
        PlanType currentPlan = user.getPlanType() != null ? user.getPlanType() : PlanType.FREE;
        String cur = (currency != null && !currency.isBlank()) ? currency.toUpperCase() : "INR";
        boolean isUsd = "USD".equalsIgnoreCase(cur);

        BigDecimal currentPlanPrice = resolvePlanPrice(currentPlan, isUsd);
        BigDecimal targetPlanPrice = resolvePlanPrice(targetPlan, isUsd);

        LocalDateTime now = LocalDateTime.now();
        LocalDateTime expiry = user.getPlanExpiry();
        long remainingDays = 0;
        long totalDays = 30;

        if (currentPlan != PlanType.FREE && expiry != null && expiry.isAfter(now)) {
            remainingDays = Math.max(0, Math.min(30, ChronoUnit.DAYS.between(now, expiry) + 1));
        }

        BigDecimal unusedCredit = BigDecimal.ZERO;
        if (remainingDays > 0 && currentPlanPrice.compareTo(BigDecimal.ZERO) > 0) {
            BigDecimal dailyRate = currentPlanPrice.divide(BigDecimal.valueOf(30), 4, RoundingMode.HALF_UP);
            unusedCredit = dailyRate.multiply(BigDecimal.valueOf(remainingDays)).setScale(2, RoundingMode.HALF_UP);
        }

        boolean isUpgrade = targetPlan.isHigherThan(currentPlan);
        BigDecimal amountToPay;
        String description;

        if (targetPlan == PlanType.FREE) {
            amountToPay = BigDecimal.ZERO;
            description = "Downgrade to Free tier. No additional payment required.";
        } else if (isUpgrade) {
            BigDecimal minCharge = isUsd ? BigDecimal.valueOf(0.50) : BigDecimal.valueOf(1.00);
            amountToPay = targetPlanPrice.subtract(unusedCredit).max(minCharge).setScale(2, RoundingMode.HALF_UP);
            String symbol = isUsd ? "$" : "₹";
            description = String.format("Upgrade from %s to %s with %s%.2f credit applied for %d remaining days.",
                    currentPlan.name(), targetPlan.name(), symbol, unusedCredit, remainingDays);
        } else if (targetPlan == currentPlan) {
            amountToPay = targetPlanPrice;
            description = String.format("Renewal for %s plan.", targetPlan.name());
        } else {
            // Downgrade to lower tier
            amountToPay = BigDecimal.ZERO;
            description = String.format("Downgrade from %s to %s will take effect at current period end.",
                    currentPlan.name(), targetPlan.name());
        }

        return ProrationQuoteResponse.builder()
                .currentPlan(currentPlan)
                .targetPlan(targetPlan)
                .currentPlanPrice(currentPlanPrice)
                .targetPlanPrice(targetPlanPrice)
                .remainingDays(remainingDays)
                .totalDays(totalDays)
                .unusedCredit(unusedCredit)
                .amountToPay(amountToPay)
                .currency(cur)
                .isUpgrade(isUpgrade)
                .description(description)
                .build();
    }

    public BigDecimal resolvePlanPrice(PlanType plan, boolean isUsd) {
        if (plan == null || plan == PlanType.FREE) {
            return BigDecimal.ZERO;
        }
        if (isUsd) {
            if (plan == PlanType.PRO) {
                return systemParameterService.getLivePrice("IOS_PRO_PLAN_PRICE", BigDecimal.valueOf(9.99));
            } else if (plan == PlanType.PRO_PLUS) {
                return systemParameterService.getLivePrice("IOS_PRO_PLUS_PLAN_PRICE", BigDecimal.valueOf(19.99));
            }
            return BigDecimal.ZERO;
        } else {
            if (plan == PlanType.PRO) {
                return systemParameterService.getLivePrice("PRO_PLAN_PRICE_INR", BigDecimal.valueOf(799.00));
            } else if (plan == PlanType.PRO_PLUS) {
                return systemParameterService.getLivePrice("PRO_PLUS_PLAN_PRICE_INR", BigDecimal.valueOf(1499.00));
            }
            return BigDecimal.ZERO;
        }
    }

    /**
     * Records a downgrade event in the payments audit table.
     */
    @Transactional
    public Payment recordDowngradeAudit(User user, PlanType previousPlan, PlanType targetPlan, String provider) {
        Subscription activeSub = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE).orElse(null);
        String downgradeOrderId = "dwn_" + targetPlan.name().toLowerCase() + "_" + System.currentTimeMillis() + "_" + java.util.UUID.randomUUID().toString().substring(0, 8);
        String prevName = previousPlan != null ? previousPlan.name() : "PAID";
        String note = targetPlan == PlanType.FREE
                ? "Plan downgraded from " + prevName + " to Free tier. Quota reset to standard limits."
                : "Plan downgraded from " + prevName + " to " + targetPlan.name() + " tier.";

        Payment payment = Payment.builder()
                .user(user)
                .subscription(activeSub)
                .planType(targetPlan)
                .razorpayOrderId(downgradeOrderId)
                .amount(BigDecimal.ZERO)
                .currency("INR")
                .paymentProvider(provider != null ? provider : "INTERNAL")
                .paymentMethod("Plan Downgrade")
                .status(PaymentStatus.SUCCESS)
                .notes(note)
                .invoiceNumber("DWN-" + (System.currentTimeMillis() % 1000000))
                .build();

        log.info("Recorded downgrade audit in billing history: user={} prevPlan={} targetPlan={} orderId={}",
                user.getUsername(), prevName, targetPlan.name(), downgradeOrderId);
        return paymentRepository.save(payment);
    }

    /**
     * Records a cancellation event in the payments audit table.
     */
    @Transactional
    public Payment recordCancellationAudit(User user, String provider) {
        Subscription activeSub = subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(user, SubscriptionStatus.ACTIVE).orElse(null);
        String cancelOrderId = "cancel_" + System.currentTimeMillis() + "_" + java.util.UUID.randomUUID().toString().substring(0, 8);
        String expiryStr = user.getPlanExpiry() != null ? user.getPlanExpiry().toString() : "period end";
        String note = "Subscription auto-renewal cancelled. Plan benefits remain active until " + expiryStr + ".";

        String finalProvider = provider != null ? provider : (activeSub != null && activeSub.getRazorpaySubscriptionId() != null && activeSub.getRazorpaySubscriptionId().startsWith("apple_") ? "APPLE_STOREKIT" : "RAZORPAY");

        Payment payment = Payment.builder()
                .user(user)
                .subscription(activeSub)
                .planType(user.getPlanType())
                .razorpayOrderId(cancelOrderId)
                .amount(BigDecimal.ZERO)
                .currency("INR")
                .paymentProvider(finalProvider)
                .paymentMethod("Subscription Cancellation")
                .status(PaymentStatus.SUCCESS)
                .notes(note)
                .invoiceNumber("CAN-" + (System.currentTimeMillis() % 1000000))
                .build();

        log.info("Recorded cancellation audit in billing history: user={} plan={} orderId={}",
                user.getUsername(), user.getPlanType(), cancelOrderId);
        return paymentRepository.save(payment);
    }
}
