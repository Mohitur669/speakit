package com.speakit.tts.service;
import com.speakit.billing.service.SubscriptionService;

import com.speakit.tts.dto.TtsRequest;
import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
import com.speakit.user.entity.User;
import com.speakit.tts.repository.TtsHistoryRepository;
import com.speakit.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TtsServiceTest {

    @Mock
    private SubscriptionService subscriptionService;
    @Mock
    private TtsHistoryRepository ttsHistoryRepository;
    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private TtsService ttsService;

    private User mockUser;

    @BeforeEach
    void setUp() {
        mockUser = new User();
        mockUser.setId(1L);
    }

    @Test
    void recordHistory_Success() {
        when(userRepository.getReferenceById(1L)).thenReturn(mockUser);
        
        ttsService.recordHistory(1L, "v1", "Voice", "NEURAL", "mp3", 100, "Hello");
        
        verify(ttsHistoryRepository, times(1)).save(any());
    }

    @Test
    void validatePlanAccess_ElevenLabs_Forbidden() {
        TtsRequest request = new TtsRequest();
        request.setVoiceId("eleven_voice");
        request.setElevenLabs(true);
        
        when(subscriptionService.canUseElevenLabs(any(), any(), any())).thenReturn(false);
        
        assertThrows(RuntimeException.class, () -> 
            ttsService.validatePlanAccess(PlanType.FREE, SubscriptionStatus.ACTIVE, LocalDateTime.now(), request, 1L)
        );
    }

    @Test
    void validatePlanAccess_Success() {
        TtsRequest request = new TtsRequest();
        request.setVoiceId("polly_voice");
        
        assertDoesNotThrow(() -> 
            ttsService.validatePlanAccess(PlanType.FREE, SubscriptionStatus.ACTIVE, LocalDateTime.now(), request, 1L)
        );
    }

    @Test
    void sumCharactersUsed_CombinesTtsAndStt() {
        java.time.LocalDate currentMonth = java.time.LocalDate.now().withDayOfMonth(1);
        com.speakit.user.repository.UsageLedgerProjection ledger = mock(com.speakit.user.repository.UsageLedgerProjection.class);
        when(ledger.getUsageMonth()).thenReturn(currentMonth);
        when(ledger.getTtsChars()).thenReturn(250L);
        when(ledger.getSttChars()).thenReturn(150L);
        when(userRepository.findUsageLedgerById(1L)).thenReturn(java.util.Optional.of(ledger));

        long total = ttsService.sumCharactersUsed(1L, LocalDateTime.now().minusDays(30));

        assertEquals(400L, total);
        verify(userRepository, times(1)).findUsageLedgerById(1L);
    }

    @Test
    void getUsageAnalytics_CalculatesBurnRateAndBreakdown() {
        java.time.LocalDate currentMonth = java.time.LocalDate.now().withDayOfMonth(1);
        com.speakit.user.repository.UsageLedgerProjection ledger = mock(com.speakit.user.repository.UsageLedgerProjection.class);
        when(ledger.getUsageMonth()).thenReturn(currentMonth);
        when(ledger.getTtsChars()).thenReturn(1500L);
        when(ledger.getSttChars()).thenReturn(500L);
        when(userRepository.findUsageLedgerById(1L)).thenReturn(java.util.Optional.of(ledger));

        when(subscriptionService.getMonthlyCharacterLimit(PlanType.PRO)).thenReturn(50000);

        var analytics = ttsService.getUsageAnalytics(1L, PlanType.PRO);

        assertNotNull(analytics);
        assertEquals("PRO", analytics.getPlan());
        assertEquals(50000L, analytics.getMonthlyLimit());
        assertEquals(2000L, analytics.getCharactersUsed());
        assertEquals(48000L, analytics.getCharactersRemaining());
        assertTrue(analytics.getBurnRatePerDay() >= 0);
        assertTrue(analytics.getProjectedDaysRemaining() > 0);
    }
}
