package com.speakit.billing.entity;

public enum SubscriptionStatus {
    CREATED,
    ACTIVE,
    TRIAL,
    PAST_DUE,
    CANCELLED,
    EXPIRED,
    SUSPENDED,
    PAYMENT_PENDING,
    @Deprecated PENDING // Legacy status, use PAYMENT_PENDING
}
