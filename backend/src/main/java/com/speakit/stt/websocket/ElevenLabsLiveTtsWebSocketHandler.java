package com.speakit.stt.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.speakit.billing.entity.PlanType;
import com.speakit.parameter.service.SystemParameterService;
import com.speakit.security.JwtService;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.AbstractWebSocketHandler;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.net.URI;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;

/**
 * Phase 4: Live Voice Bridge — ElevenLabs Streaming TTS WebSocket Proxy.
 *
 * Flow:
 *   iOS client → /ws/live-tts?token=JWT&voiceId=xxx
 *   → Backend validates JWT, checks PRO_PLUS plan gate
 *   → Opens ElevenLabs streaming TTS WS (wss://api.elevenlabs.io/v1/text-to-speech/{voiceId}/stream-input)
 *   → Forwards text JSON chunks from iOS → ElevenLabs upstream
 *   → Receives binary audio (MP3) frames from ElevenLabs → forwards to iOS
 *
 * ElevenLabs Streaming TTS Protocol:
 *   - Send: {"text":"sentence chunk","try_trigger_generation":true}
 *   - Send: {"text":""} to flush and close
 *   - Receive: binary MP3 audio chunks (stream them directly to client for playback)
 *   - Model: eleven_flash_v2_5 (lowest latency, ~75ms first chunk)
 *
 * Plan Gate: PRO_PLUS and above only.
 * Target latency: < 800ms end-to-end (Sarvam STT ~100-200ms + ElevenLabs TTS ~75ms + network).
 */
@Component
@Slf4j
public class ElevenLabsLiveTtsWebSocketHandler extends AbstractWebSocketHandler {

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper;
    private final SystemParameterService systemParameterService;

    public ElevenLabsLiveTtsWebSocketHandler(
            JwtService jwtService,
            UserRepository userRepository,
            ObjectMapper objectMapper,
            SystemParameterService systemParameterService) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.objectMapper = objectMapper;
        this.systemParameterService = systemParameterService;
    }

    @Value("${elevenlabs.apiKey:}")
    private String elevenLabsApiKey;

    // ElevenLabs streaming TTS base URL
    private static final String EL_STREAM_BASE = "wss://api.elevenlabs.io/v1/text-to-speech/%s/stream-input?model_id=eleven_flash_v2_5&output_format=mp3_44100_128";

    // Tracks upstream ElevenLabs sessions per client session ID
    private final Map<String, WebSocketSession> upstreamSessions = new ConcurrentHashMap<>();
    private final Map<String, AtomicBoolean> upstreamReady = new ConcurrentHashMap<>();

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String query = session.getUri() != null ? session.getUri().getQuery() : null;

        // --- Authentication: JWT from ?token= query param ---
        String token = extractParam(query, "token");
        if (token == null) {
            log.warn("Live TTS WS: Missing token. Closing session {}", session.getId());
            session.close(new CloseStatus(4001, "Authentication required"));
            return;
        }

        String username;
        try {
            username = jwtService.extractUsername(token);
        } catch (Exception e) {
            log.warn("Live TTS WS: Invalid JWT. Closing session {}", session.getId());
            session.close(new CloseStatus(4001, "Invalid token"));
            return;
        }

        // --- Feature Flag Gate: VOICE_BRIDGE_FLAG ---
        if (!systemParameterService.isVoiceBridgeEnabled()) {
            log.info("Live TTS WS: Connection rejected for user={}. Voice Bridge is disabled by feature flag.", username);
            session.close(new CloseStatus(4003, "Voice Bridge feature is currently disabled"));
            return;
        }

        Optional<User> userOpt = userRepository.findByUsername(username.toLowerCase());
        if (userOpt.isEmpty()) {
            log.warn("Live TTS WS: User not found for {}. Closing session {}", username, session.getId());
            session.close(new CloseStatus(4001, "User not found"));
            return;
        }

        User user = userOpt.get();

        // --- Plan Gate: PRO_PLUS and above only ---
        PlanType plan = user.getPlanType() != null ? user.getPlanType() : PlanType.FREE;
        if (plan.getRank() < PlanType.PRO_PLUS.getRank()) {
            log.info("Live TTS WS: Access denied for user={} (plan={}). PRO_PLUS required.", username, plan);
            session.close(new CloseStatus(4003, "Live Voice Bridge requires Pro Plus plan"));
            return;
        }

        // --- Voice ID from ?voiceId= query param ---
        String voiceId = extractParam(query, "voiceId");
        if (voiceId == null || !voiceId.matches("^[a-zA-Z0-9_-]+$")) {
            log.warn("Live TTS WS: Missing or invalid voiceId for user={}. Closing session {}", username, session.getId());
            session.close(new CloseStatus(4004, "Valid voiceId query parameter is required"));
            return;
        }

        if (elevenLabsApiKey == null || elevenLabsApiKey.isBlank()) {
            log.error("Live TTS WS: ElevenLabs API key not configured. Closing session {}", session.getId());
            session.close(new CloseStatus(1011, "TTS service not configured"));
            return;
        }

        log.info("Live TTS WS: Client connected: user={}, plan={}, voiceId={}, sessionId={}",
                username, plan, voiceId, session.getId());

        // Store auth context on session
        session.getAttributes().put("username", username);
        session.getAttributes().put("userId", user.getId());
        session.getAttributes().put("voiceId", voiceId);

        // Open ElevenLabs upstream WebSocket
        openUpstreamSession(session, voiceId);
    }

    @Override
    protected void handleTextMessage(WebSocketSession clientSession, TextMessage message) throws Exception {
        // Forward text chunk JSON from iOS client → ElevenLabs upstream
        WebSocketSession upstream = upstreamSessions.get(clientSession.getId());
        if (upstream == null || !upstream.isOpen()) {
            log.warn("Live TTS WS: Upstream not available for session {}. Re-opening.", clientSession.getId());
            String voiceId = (String) clientSession.getAttributes().get("voiceId");
            if (voiceId != null) {
                openUpstreamSession(clientSession, voiceId);
            }
            return;
        }

        // iOS sends: {"text":"sentence chunk","try_trigger_generation":true}
        // or: {"text":""} to flush/end
        String payload = message.getPayload();
        log.debug("Live TTS WS: Forwarding text chunk ({} chars) for session {}", payload.length(), clientSession.getId());

        try {
            upstream.sendMessage(new TextMessage(payload));
        } catch (IOException e) {
            log.error("Live TTS WS: Failed to forward text to ElevenLabs for session {}", clientSession.getId(), e);
        }
    }

    @Override
    protected void handleBinaryMessage(WebSocketSession clientSession, BinaryMessage message) {
        // iOS should not be sending binary — ignore but log
        log.debug("Live TTS WS: Unexpected binary from iOS client session {}", clientSession.getId());
    }

    @Override
    public void afterConnectionClosed(WebSocketSession clientSession, CloseStatus status) {
        log.info("Live TTS WS: Client disconnected: sessionId={}, status={}", clientSession.getId(), status);
        closeUpstream(clientSession.getId());
    }

    @Override
    public void handleTransportError(WebSocketSession clientSession, Throwable exception) {
        log.error("Live TTS WS: Transport error for session {}", clientSession.getId(), exception);
        closeUpstream(clientSession.getId());
    }

    // --- Internal helpers ---

    /**
     * Opens an ElevenLabs streaming TTS WebSocket for the given client session.
     * Sends the BOS (beginning-of-stream) initialization message with voice settings.
     * Receives binary MP3 audio chunks and forwards them back to the iOS client.
     */
    private void openUpstreamSession(WebSocketSession clientSession, String voiceId) {
        String elUrl = String.format(EL_STREAM_BASE, voiceId);
        AtomicBoolean ready = new AtomicBoolean(false);
        upstreamReady.put(clientSession.getId(), ready);

        StandardWebSocketClient wsClient = new StandardWebSocketClient();

        // Upstream handler: ElevenLabs → iOS client
        TextWebSocketHandler upstreamHandler = new TextWebSocketHandler() {
            @Override
            public void afterConnectionEstablished(WebSocketSession upstream) throws Exception {
                log.info("Live TTS WS: ElevenLabs upstream connected for clientSession={}", clientSession.getId());
                upstreamSessions.put(clientSession.getId(), upstream);
                ready.set(true);

                // Send BOS (beginning of stream) message with voice settings
                Map<String, Object> bos = new LinkedHashMap<>();
                bos.put("text", " ");
                bos.put("voice_settings", Map.of(
                        "stability", 0.5,
                        "similarity_boost", 0.75,
                        "use_speaker_boost", true
                ));
                bos.put("xi_api_key", elevenLabsApiKey);
                bos.put("try_trigger_generation", true);
                upstream.sendMessage(new TextMessage(objectMapper.writeValueAsString(bos)));
            }

            @Override
            protected void handleTextMessage(WebSocketSession upstream, TextMessage message) {
                // ElevenLabs may send JSON metadata (not audio); parse and ignore or forward
                log.debug("Live TTS WS: ElevenLabs upstream text frame: {}", message.getPayload());
            }

            @Override
            protected void handleBinaryMessage(WebSocketSession upstream, BinaryMessage message) {
                // Forward binary MP3 audio chunk to iOS client
                if (clientSession.isOpen()) {
                    try {
                        clientSession.sendMessage(message);
                        log.debug("Live TTS WS: Forwarded {} audio bytes to iOS client session {}",
                                message.getPayloadLength(), clientSession.getId());
                    } catch (IOException e) {
                        log.error("Live TTS WS: Failed to forward audio to iOS client session {}",
                                clientSession.getId(), e);
                    }
                }
            }

            @Override
            public void afterConnectionClosed(WebSocketSession upstream, CloseStatus status) {
                log.info("Live TTS WS: ElevenLabs upstream closed: clientSession={}, status={}",
                        clientSession.getId(), status);
                upstreamSessions.remove(clientSession.getId());
                ready.set(false);

                // Signal EOS to iOS client if still open
                if (clientSession.isOpen()) {
                    try {
                        clientSession.sendMessage(new TextMessage("{\"type\":\"audio_end\"}"));
                    } catch (IOException ignored) {}
                }
            }

            @Override
            public void handleTransportError(WebSocketSession upstream, Throwable exception) {
                log.error("Live TTS WS: ElevenLabs upstream transport error for clientSession={}",
                        clientSession.getId(), exception);
                upstreamSessions.remove(clientSession.getId());
                ready.set(false);
            }
        };

        try {
            WebSocketHttpHeaders elHeaders = new WebSocketHttpHeaders();
            // API key passed in BOS message — no header auth needed for streaming endpoint
            wsClient.execute(upstreamHandler, elHeaders, URI.create(elUrl));
            log.info("Live TTS WS: Connecting to ElevenLabs upstream: voiceId={}, sessionId={}", voiceId, clientSession.getId());
        } catch (Exception e) {
            log.error("Live TTS WS: Failed to connect to ElevenLabs upstream for session {}", clientSession.getId(), e);
            try {
                clientSession.close(new CloseStatus(1011, "Failed to connect to TTS upstream"));
            } catch (IOException ignored) {}
        }
    }

    private void closeUpstream(String clientSessionId) {
        WebSocketSession upstream = upstreamSessions.remove(clientSessionId);
        upstreamReady.remove(clientSessionId);
        if (upstream != null && upstream.isOpen()) {
            try {
                // Send EOS flush signal before closing
                upstream.sendMessage(new TextMessage("{\"text\":\"\"}"));
                upstream.close(CloseStatus.NORMAL);
            } catch (IOException e) {
                log.warn("Live TTS WS: Error closing ElevenLabs upstream for clientSession={}", clientSessionId);
            }
        }
    }

    /**
     * Extracts a named query parameter value from a raw query string.
     * Returns null if the parameter is absent or empty.
     */
    private String extractParam(String query, String paramName) {
        if (query == null) return null;
        for (String part : query.split("&")) {
            if (part.startsWith(paramName + "=")) {
                String value = part.substring(paramName.length() + 1);
                return value.isEmpty() ? null : value;
            }
        }
        return null;
    }
}
