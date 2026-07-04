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
    private LocalDateTime createdAt;
}
