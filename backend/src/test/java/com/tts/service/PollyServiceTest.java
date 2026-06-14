package com.tts.service;

import com.tts.entity.PlanType;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import software.amazon.awssdk.services.polly.PollyClient;
import software.amazon.awssdk.services.polly.model.Engine;
import software.amazon.awssdk.services.polly.model.Voice;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class PollyServiceTest {

    @InjectMocks
    private PollyService pollyService;

    @Mock
    private PollyClient pollyClient;

    @Test
    void getBestEngineForVoice_Neural() {
        // We need to spy on pollyService because getRawAvailableVoices() is called internally
        PollyService spyService = spy(pollyService);
        
        Voice neuralVoice = Voice.builder()
                .id("Joanna")
                .supportedEngines(Engine.NEURAL, Engine.STANDARD)
                .build();
        
        doReturn(List.of(neuralVoice)).when(spyService).getRawAvailableVoices();
        
        // Premium user should get Neural
        Engine engine = spyService.getBestEngineForVoice("Joanna", PlanType.PRO);
        
        assertEquals(Engine.NEURAL, engine);
    }

    @Test
    void getBestEngineForVoice_StandardOnly() {
        PollyService spyService = spy(pollyService);
        
        Voice standardVoice = Voice.builder()
                .id("Justin")
                .supportedEngines(Engine.STANDARD)
                .build();
        
        doReturn(List.of(standardVoice)).when(spyService).getRawAvailableVoices();
        
        Engine engine = spyService.getBestEngineForVoice("Justin", PlanType.FREE);
        
        assertEquals(Engine.STANDARD, engine);
    }

    @Test
    void getBestEngineForVoice_NeuralFallbackForFreeUser() {
        PollyService spyService = spy(pollyService);
        
        Voice neuralVoice = Voice.builder()
                .id("Joanna")
                .supportedEngines(Engine.NEURAL, Engine.STANDARD)
                .build();
        
        doReturn(List.of(neuralVoice)).when(spyService).getRawAvailableVoices();
        
        // Free user should be restricted to Standard even if Neural is available
        Engine engine = spyService.getBestEngineForVoice("Joanna", PlanType.FREE);
        
        assertEquals(Engine.STANDARD, engine);
    }
}
