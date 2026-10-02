package com.speakit.billing.dto;

import jakarta.validation.constraints.NotBlank;
import lombok.Data;

/**
 * Request payload sent by the iOS app after a successful StoreKit 2 purchase.
 * The backend uses the productId to map the Apple product to an internal PlanType
 * and updates the user's subscription accordingly.
 *
 * Note: Full Apple JWS receipt verification requires the Apple App Store Server API
 * (paid Apple Developer account). For local StoreKit config (sandbox) testing,
 * we trust the productId directly. Production should verify the JWS token.
 */
@Data
public class AppleVerificationRequest {

    /**
     * The Apple App Store transaction ID returned by StoreKit 2 after purchase.
     * Used as the gateway subscription ID for audit trail / idempotency.
     */
    @NotBlank
    private String transactionId;

    /**
     * The StoreKit product ID purchased by the user.
     * e.g. "com.speakit.pro" or "com.speakit.proplus"
     */
    @NotBlank
    private String productId;
}
