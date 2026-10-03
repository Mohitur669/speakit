package com.speakit.stt.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.speakit.billing.entity.PlanType;
import com.speakit.security.JwtService;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import com.speakit.parameter.service.SystemParameterService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.*;
import org.springframework.web.socket.*;

import java.net.URI;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import static org.mockito.Mockito.*;

/**
 * Unit tests for ElevenLabsLiveTtsWebSocketHandler.
 * Verifies plan gating, JWT validation, and voiceId validation.
 */
class ElevenLabsLiveTtsWebSocketHandlerTest {

    @InjectMocks
    private ElevenLabsLiveTtsWebSocketHandler handler;

    @Mock
    private JwtService jwtService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private ObjectMapper objectMapper;

    @Mock
    private SystemParameterService systemParameterService;

    @Mock
    private WebSocketSession session;

    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        // Provide a safe map for session attributes
        Map<String, Object> attributes = new HashMap<>();
        when(session.getAttributes()).thenReturn(attributes);
        when(session.getId()).thenReturn("test-session-live-tts");
        // Default feature flag to enabled so other tests test their specific logic
        when(systemParameterService.isVoiceBridgeEnabled()).thenReturn(true);
    }

    @Test
    void rejectConnection_whenNoToken() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?voiceId=abc123"));

        handler.afterConnectionEstablished(session);

        verify(session).close(argThat(cs -> cs.getCode() == 4001));
    }

    @Test
    void rejectConnection_whenInvalidToken() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?token=bad&voiceId=abc123"));
        when(jwtService.extractUsername("bad")).thenThrow(new RuntimeException("Invalid JWT"));

        handler.afterConnectionEstablished(session);

        verify(session).close(argThat(cs -> cs.getCode() == 4001));
    }

    @Test
    void rejectConnection_whenUserIsFreePlan() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?token=valid&voiceId=abc123"));
        when(jwtService.extractUsername("valid")).thenReturn("freeuser");

        User freeUser = mock(User.class);
        when(freeUser.getPlanType()).thenReturn(PlanType.FREE);
        when(freeUser.getId()).thenReturn(1L);
        when(userRepository.findByUsername("freeuser")).thenReturn(Optional.of(freeUser));

        handler.afterConnectionEstablished(session);

        // Should close with 4003 (plan gate)
        verify(session).close(argThat(cs -> cs.getCode() == 4003));
    }

    @Test
    void rejectConnection_whenUserIsProPlan_notPlusOrAbove() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?token=valid&voiceId=abc123"));
        when(jwtService.extractUsername("valid")).thenReturn("prouser");

        User proUser = mock(User.class);
        when(proUser.getPlanType()).thenReturn(PlanType.PRO);
        when(proUser.getId()).thenReturn(2L);
        when(userRepository.findByUsername("prouser")).thenReturn(Optional.of(proUser));

        handler.afterConnectionEstablished(session);

        // PRO is rank 1, PRO_PLUS is rank 2 — should be gated
        verify(session).close(argThat(cs -> cs.getCode() == 4003));
    }

    @Test
    void rejectConnection_whenVoiceIdMissing() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?token=valid"));
        when(jwtService.extractUsername("valid")).thenReturn("ppuser");

        User ppUser = mock(User.class);
        when(ppUser.getPlanType()).thenReturn(PlanType.PRO_PLUS);
        when(ppUser.getId()).thenReturn(3L);
        when(userRepository.findByUsername("ppuser")).thenReturn(Optional.of(ppUser));

        handler.afterConnectionEstablished(session);

        // Missing voiceId → close 4004
        verify(session).close(argThat(cs -> cs.getCode() == 4004));
    }

    @Test
    void rejectConnection_whenApiKeyNotConfigured() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?token=valid&voiceId=abc123"));
        when(jwtService.extractUsername("valid")).thenReturn("ppuser");

        User ppUser = mock(User.class);
        when(ppUser.getPlanType()).thenReturn(PlanType.PRO_PLUS);
        when(ppUser.getId()).thenReturn(3L);
        when(userRepository.findByUsername("ppuser")).thenReturn(Optional.of(ppUser));

        // apiKey is blank by default (not injected in test) → should close 1011
        handler.afterConnectionEstablished(session);

        verify(session).close(argThat(cs -> cs.getCode() == 1011));
    }

    @Test
    void rejectConnection_whenVoiceBridgeFeatureDisabled() throws Exception {
        when(session.getUri()).thenReturn(URI.create("ws://localhost/ws/live-tts?token=valid&voiceId=abc123"));
        when(jwtService.extractUsername("valid")).thenReturn("ppuser");
        when(systemParameterService.isVoiceBridgeEnabled()).thenReturn(false);

        handler.afterConnectionEstablished(session);

        // Feature flag disabled → close 4003 with disabled reason
        verify(session).close(argThat(cs -> cs.getCode() == 4003 && "Voice Bridge feature is currently disabled".equals(cs.getReason())));
    }
}
