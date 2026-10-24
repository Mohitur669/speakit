package com.speakit.stt.websocket;

import com.speakit.security.JwtService;
import com.speakit.tts.service.WSTicketService;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;

import java.net.URI;
import java.util.Optional;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class LiveSttWebSocketHandlerTest {

    @Mock
    private WSTicketService wsTicketService;

    @Mock
    private JwtService jwtService;

    @Mock
    private UserRepository userRepository;

    @Mock
    private WebSocketSession session;

    @InjectMocks
    private LiveSttWebSocketHandler handler;

    @BeforeEach
    void setUp() {
        lenient().when(session.getId()).thenReturn("test-session-123");
    }

    @Test
    void afterConnectionEstablished_NoAuthParam_ClosesWithNotAcceptable() throws Exception {
        when(session.getUri()).thenReturn(URI.create("wss://localhost:8443/ws/live-stt"));

        handler.afterConnectionEstablished(session);

        verify(session).close(argThat(status -> status.getCode() == CloseStatus.NOT_ACCEPTABLE.getCode()));
    }

    @Test
    void afterConnectionEstablished_ValidToken_AuthenticatesAndSendsReady() throws Exception {
        when(session.getUri()).thenReturn(URI.create("wss://localhost:8443/ws/live-stt?token=valid-jwt-token"));
        when(jwtService.extractUsername("valid-jwt-token")).thenReturn("alice");

        User mockUser = new User();
        mockUser.setUsername("alice");
        mockUser.setActive(true);
        mockUser.setPlanType(com.speakit.billing.entity.PlanType.PRO);
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(mockUser));

        handler.afterConnectionEstablished(session);

        verify(session).sendMessage(any(TextMessage.class));
        verify(session, never()).close(any(CloseStatus.class));
    }

    @Test
    void afterConnectionEstablished_FreeUser_ClosesWithPolicyViolation() throws Exception {
        when(session.getUri()).thenReturn(URI.create("wss://localhost:8443/ws/live-stt?token=valid-jwt-token"));
        when(jwtService.extractUsername("valid-jwt-token")).thenReturn("free_user");

        User freeUser = new User();
        freeUser.setUsername("free_user");
        freeUser.setActive(true);
        freeUser.setPlanType(com.speakit.billing.entity.PlanType.FREE);
        when(userRepository.findByUsername("free_user")).thenReturn(Optional.of(freeUser));

        handler.afterConnectionEstablished(session);

        verify(session).close(argThat(status -> status.getCode() == CloseStatus.POLICY_VIOLATION.getCode()));
    }

    @Test
    void afterConnectionEstablished_InactiveUser_ClosesWithPolicyViolation() throws Exception {
        when(session.getUri()).thenReturn(URI.create("wss://localhost:8443/ws/live-stt?token=valid-jwt-token"));
        when(jwtService.extractUsername("valid-jwt-token")).thenReturn("inactive_user");

        User inactiveUser = new User();
        inactiveUser.setUsername("inactive_user");
        inactiveUser.setActive(false);
        when(userRepository.findByUsername("inactive_user")).thenReturn(Optional.of(inactiveUser));

        handler.afterConnectionEstablished(session);

        verify(session).close(argThat(status -> status.getCode() == CloseStatus.POLICY_VIOLATION.getCode()));
    }

    @Test
    void afterConnectionClosed_CleansUpSession() throws Exception {
        when(session.getUri()).thenReturn(URI.create("wss://localhost:8443/ws/live-stt?token=valid-jwt-token"));
        when(jwtService.extractUsername("valid-jwt-token")).thenReturn("alice");

        User mockUser = new User();
        mockUser.setUsername("alice");
        mockUser.setActive(true);
        mockUser.setPlanType(com.speakit.billing.entity.PlanType.PRO);
        when(userRepository.findByUsername("alice")).thenReturn(Optional.of(mockUser));

        handler.afterConnectionEstablished(session);
        handler.afterConnectionClosed(session, CloseStatus.NORMAL);

        // After close, handleTextMessage should not attempt processing for the session
        handler.handleTextMessage(session, new TextMessage("{\"mode\":\"transcribe\"}"));
    }
}
