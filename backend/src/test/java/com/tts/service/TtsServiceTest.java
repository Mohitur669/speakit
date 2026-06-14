package com.tts.service;

import com.tts.dto.TtsRequest;
import com.tts.entity.PlanType;
import com.tts.entity.SubscriptionStatus;
import com.tts.entity.User;
import com.tts.repository.TtsHistoryRepository;
import com.tts.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.LocalDateTime;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertThrows;
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
}
