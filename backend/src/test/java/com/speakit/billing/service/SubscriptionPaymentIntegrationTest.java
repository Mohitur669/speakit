package com.speakit.billing.service;

import com.speakit.billing.dto.PaymentOrderRequest;
import com.speakit.billing.dto.PaymentOrderResponse;
import com.speakit.billing.dto.PaymentVerificationRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.Subscription;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.billing.repository.PaymentRepository;
import com.speakit.billing.repository.SubscriptionRepository;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import com.speakit.billing.config.RazorpayConfig;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class SubscriptionPaymentIntegrationTest {

    @Mock
    private PaymentRepository paymentRepository;

    @Mock
    private SubscriptionRepository subscriptionRepository;

    @Mock
    private UserRepository userRepository;

    @Mock
    private SystemParameterService systemParameterService;

    @Mock
    private RazorpayConfig razorpayConfig;

    private SubscriptionManagementService subscriptionManagementService;
    private RazorpayService razorpayService;
    private User testUser;

    @BeforeEach
    void setUp() {
        subscriptionManagementService = new SubscriptionManagementService(
                userRepository,
                subscriptionRepository,
                null
        );

        razorpayService = new RazorpayService(
                null,
                razorpayConfig,
                paymentRepository,
                subscriptionRepository,
                systemParameterService,
                subscriptionManagementService
        );

        testUser = User.builder()
                .id(100L)
                .username("testcoder")
                .email("testcoder@speakit.local")
                .planType(PlanType.FREE)
                .subscriptionStatus(SubscriptionStatus.ACTIVE)
                .build();
    }

    @Test
    void createOrder_generatesSandboxOrderWhenPlanIdEmpty() throws Exception {
        when(systemParameterService.getLivePrice(anyString(), any())).thenReturn(new BigDecimal("499"));
        lenient().when(systemParameterService.getLiveParameter(eq("PRO_PLAN_ID_RAZORPAY"), anyString())).thenReturn("");
        lenient().when(systemParameterService.getParameter(eq("PRO_PLAN_ID_RAZORPAY"), anyString())).thenReturn("");
        lenient().when(systemParameterService.getIntParameter(anyString(), anyInt())).thenReturn(60);
        when(razorpayConfig.getKeyId()).thenReturn("rzp_test_placeholder");

        PaymentOrderRequest request = PaymentOrderRequest.builder()
                .planType("PRO")
                .amount(new BigDecimal("499"))
                .currency("INR")
                .build();

        PaymentOrderResponse response = razorpayService.createOrder(request, testUser);

        assertNotNull(response);
        assertNotNull(response.getSubscriptionId());
        assertTrue(response.getSubscriptionId().startsWith("sub_sim_"));
        assertEquals(49900, response.getAmount());
        assertEquals("INR", response.getCurrency());
    }

    @Test
    void createOrder_doesNotOverwritePreviousPendingSubscriptionPlan() throws Exception {
        // User first creates order for PRO
        when(systemParameterService.getLivePrice(eq("PRO_PLAN_PRICE_INR"), any())).thenReturn(new BigDecimal("1"));
        when(systemParameterService.getLivePrice(eq("PRO_PLUS_PLAN_PRICE_INR"), any())).thenReturn(new BigDecimal("2"));
        lenient().when(systemParameterService.getLiveParameter(anyString(), anyString())).thenReturn("");
        lenient().when(systemParameterService.getParameter(anyString(), anyString())).thenReturn("");
        lenient().when(systemParameterService.getIntParameter(anyString(), anyInt())).thenReturn(60);
        when(razorpayConfig.getKeyId()).thenReturn("rzp_test_placeholder");

        org.mockito.ArgumentCaptor<com.speakit.billing.entity.Payment> paymentCaptor =
                org.mockito.ArgumentCaptor.forClass(com.speakit.billing.entity.Payment.class);

        // 1. Order for PRO
        PaymentOrderRequest proRequest = PaymentOrderRequest.builder()
                .planType("PRO")
                .amount(new BigDecimal("1"))
                .currency("INR")
                .build();
        razorpayService.createOrder(proRequest, testUser);

        // 2. Order for PRO_PLUS without completing the first one
        PaymentOrderRequest proPlusRequest = PaymentOrderRequest.builder()
                .planType("PRO_PLUS")
                .amount(new BigDecimal("2"))
                .currency("INR")
                .build();
        razorpayService.createOrder(proPlusRequest, testUser);

        // Verify both payments were saved with their respective, distinct immutable plan types
        verify(paymentRepository, times(2)).save(paymentCaptor.capture());
        var savedPayments = paymentCaptor.getAllValues();
        assertEquals(2, savedPayments.size());
        assertEquals(PlanType.PRO, savedPayments.get(0).getPlanType());
        assertEquals(PlanType.PRO_PLUS, savedPayments.get(1).getPlanType());
    }

    @Test
    void upgradeUser_calculatesOneMonthValidity() {
        LocalDateTime beforeUpgrade = LocalDateTime.now();

        subscriptionManagementService.upgradeUser(testUser, PlanType.PRO, "sub_sim_test123");

        assertEquals(PlanType.PRO, testUser.getPlanType());
        assertEquals(SubscriptionStatus.ACTIVE, testUser.getSubscriptionStatus());
        assertNotNull(testUser.getPlanExpiry());
        assertTrue(testUser.getPlanExpiry().isAfter(beforeUpgrade.plusDays(27)));
        assertTrue(testUser.getPlanExpiry().isBefore(beforeUpgrade.plusDays(32)));

        verify(userRepository, times(1)).save(testUser);
        verify(subscriptionRepository, times(1)).save(any(Subscription.class));
    }

    @Test
    void demoteUserToFree_clearsPlanExpiry() {
        testUser.setPlanType(PlanType.PRO);
        testUser.setPlanExpiry(LocalDateTime.now().plusDays(20));

        subscriptionManagementService.demoteUserToFree(testUser);

        assertEquals(PlanType.FREE, testUser.getPlanType());
        assertEquals(SubscriptionStatus.ACTIVE, testUser.getSubscriptionStatus());
        assertNull(testUser.getPlanExpiry());

        verify(userRepository, times(1)).save(testUser);
    }
}
