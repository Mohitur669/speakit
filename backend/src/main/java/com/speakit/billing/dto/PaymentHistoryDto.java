package com.speakit.billing.dto;

import lombok.Builder;
import lombok.Data;
import java.math.BigDecimal;
import java.time.LocalDateTime;

@Data
@Builder
public class PaymentHistoryDto {
    private Long id;
    private String planName;
    private BigDecimal amount;
    private String currency;
    private String status;
    private String razorpayOrderId;
    private String paymentProvider;
    private String paymentMethod;
    private String transactionId;
    private String invoiceNote;
    @com.fasterxml.jackson.annotation.JsonFormat(shape = com.fasterxml.jackson.annotation.JsonFormat.Shape.STRING, pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime createdAt;
}
