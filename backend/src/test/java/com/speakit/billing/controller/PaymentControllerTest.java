package com.speakit.billing.controller;

import com.speakit.billing.dto.AppleVerificationRequest;
import com.speakit.billing.dto.PaymentHistoryDto;
import com.speakit.billing.dto.ProrationQuoteResponse;
import com.speakit.billing.entity.Payment;
import com.speakit.billing.entity.PaymentStatus;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.repository.SubscriptionRepository;
import com.speakit.billing.service.RazorpayService;
import com.speakit.billing.service.SubscriptionManagementService;
import com.speakit.user.entity.User;
import com.speakit.user.service.UserService;
import jakarta.servlet.http.HttpServletRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.web.PagedModel;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PaymentControllerTest {

    @Mock
    private RazorpayService razorpayService;

    @Mock
    private UserService userService;

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private SubscriptionRepository subscriptionRepository;

    @Mock
    private SubscriptionManagementService subscriptionManagementService;

    @Mock
    private HttpServletRequest httpRequest;

    private PaymentController paymentController;

    private User testUser;

    @BeforeEach
    void setUp() {
        paymentController = new PaymentController(
                razorpayService,
                userService,
                paymentRepository,
                subscriptionRepository,
                subscriptionManagementService
        );

        testUser = User.builder()
                .id(100L)
                .username("apple_tester")
                .email("apple_tester@example.com")
                .planType(PlanType.FREE)
                .build();
    }

    @Test
    void verifyApplePurchase_recordsStoreKitPaymentInBillingHistory() {
        when(httpRequest.getAttribute("userId")).thenReturn(100L);
        when(userService.getUserById(100L)).thenReturn(testUser);
        when(paymentRepository.findByRazorpayOrderId("apple_tx_apple_999")).thenReturn(Optional.empty());
        when(subscriptionRepository.findFirstByUserAndStatusOrderByIdDesc(eq(testUser), any())).thenReturn(Optional.empty());

        AppleVerificationRequest request = new AppleVerificationRequest();
        request.setProductId("com.speakit.pro");
        request.setTransactionId("tx_apple_999");
        request.setAmount(BigDecimal.valueOf(799.00));
        request.setCurrency("INR");

        ResponseEntity<String> response = paymentController.verifyApplePurchase(request, httpRequest);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue(response.getBody().contains("PRO"));

        verify(subscriptionManagementService).upgradeUser(eq(testUser), eq(PlanType.PRO), eq("apple_tx_apple_999"));

        ArgumentCaptor<Payment> paymentCaptor = ArgumentCaptor.forClass(Payment.class);
        verify(paymentRepository).save(paymentCaptor.capture());
        Payment savedPayment = paymentCaptor.getValue();

        assertEquals("APPLE_STOREKIT", savedPayment.getPaymentProvider());
        assertEquals("In-App Purchase (Apple ID)", savedPayment.getPaymentMethod());
        assertEquals("tx_apple_999", savedPayment.getRazorpayPaymentId());
        assertEquals("apple_tx_apple_999", savedPayment.getRazorpayOrderId());
        assertEquals(PaymentStatus.SUCCESS, savedPayment.getStatus());
        assertEquals(PlanType.PRO, savedPayment.getPlanType());
        assertEquals(BigDecimal.valueOf(799.00), savedPayment.getAmount());
        assertEquals("INR", savedPayment.getCurrency());
    }

    @Test
    void getPaymentHistory_populatesStoreKitMetadataAndInvoiceNote() {
        when(httpRequest.getAttribute("userId")).thenReturn(100L);

        Payment applePayment = Payment.builder()
                .id(1L)
                .user(testUser)
                .planType(PlanType.PRO)
                .razorpayOrderId("apple_tx_12345")
                .razorpayPaymentId("tx_12345")
                .paymentProvider("APPLE_STOREKIT")
                .paymentMethod("In-App Purchase (Apple ID)")
                .amount(BigDecimal.valueOf(799.00))
                .currency("INR")
                .status(PaymentStatus.SUCCESS)
                .build();

        Page<Payment> page = new PageImpl<>(List.of(applePayment), PageRequest.of(0, 20), 1);
        when(paymentRepository.findByUserIdOrderByCreatedAtDesc(eq(100L), any())).thenReturn(page);

        ResponseEntity<PagedModel<PaymentHistoryDto>> response = paymentController.getPaymentHistory(httpRequest, 0, 20);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());

        List<PaymentHistoryDto> dtoList = response.getBody().getContent().stream().toList();
        assertEquals(1, dtoList.size());

        PaymentHistoryDto dto = dtoList.get(0);
        assertEquals("APPLE_STOREKIT", dto.getPaymentProvider());
        assertEquals("In-App Purchase (Apple ID)", dto.getPaymentMethod());
        assertEquals("tx_12345", dto.getTransactionId());
        assertNotNull(dto.getInvoiceNote());
        assertTrue(dto.getInvoiceNote().contains("Apple ID email"));
    }

    @Test
    void getProrationQuote_returnsCalculatedQuote() {
        when(httpRequest.getAttribute("userId")).thenReturn(100L);
        when(userService.getUserById(100L)).thenReturn(testUser);

        ProrationQuoteResponse mockQuote = ProrationQuoteResponse.builder()
                .currentPlan(PlanType.FREE)
                .targetPlan(PlanType.PRO_PLUS)
                .amountToPay(BigDecimal.valueOf(1499.00))
                .unusedCredit(BigDecimal.ZERO)
                .currency("INR")
                .isUpgrade(true)
                .description("Upgrade to PRO_PLUS")
                .build();

        when(subscriptionManagementService.calculateProrationQuote(eq(testUser), eq(PlanType.PRO_PLUS), eq("INR")))
                .thenReturn(mockQuote);

        ResponseEntity<ProrationQuoteResponse> response = paymentController.getProrationQuote("PRO_PLUS", "INR", httpRequest);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertNotNull(response.getBody());
        assertEquals(BigDecimal.valueOf(1499.00), response.getBody().getAmountToPay());
        assertTrue(response.getBody().isUpgrade());
    }

    @Test
    void downgradePlan_toFree_recordsAudit() {
        testUser.setPlanType(PlanType.PRO);
        when(httpRequest.getAttribute("userId")).thenReturn(100L);
        when(userService.getUserById(100L)).thenReturn(testUser);

        ResponseEntity<String> response = paymentController.downgradePlan(PlanType.FREE, null, httpRequest);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue(response.getBody().contains("Free tier"));
        verify(subscriptionManagementService).demoteUserToFree(testUser);
        verify(subscriptionManagementService).recordDowngradeAudit(testUser, PlanType.PRO, PlanType.FREE, "INTERNAL");
    }

    @Test
    void cancelSubscription_schedulesCancellationAndRecordsAudit() {
        testUser.setPlanType(PlanType.PRO);
        when(httpRequest.getAttribute("userId")).thenReturn(100L);
        when(userService.getUserById(100L)).thenReturn(testUser);

        ResponseEntity<String> response = paymentController.cancelSubscription(httpRequest);

        assertEquals(HttpStatus.OK, response.getStatusCode());
        assertTrue(response.getBody().contains("cancellation"));
        verify(subscriptionManagementService).cancelSubscription(testUser);
        verify(subscriptionManagementService).recordCancellationAudit(testUser, null);
    }
}
