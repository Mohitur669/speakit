package com.speakit.billing.entity;

public enum PaymentStatus {
    INITIATED,
    PENDING,
    SUCCESS,
    FAILED,
    REFUNDED,
    PARTIALLY_REFUNDED,
    CHARGEBACK
}
