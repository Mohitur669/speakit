package com.speakit.stt.websocket;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.speakit.billing.entity.PlanType;
import com.speakit.security.JwtService;
import com.speakit.tts.service.WSTicketService;
import com.speakit.user.entity.User;
import com.speakit.user.repository.UserRepository;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.*;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.handler.AbstractWebSocketHandler;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;
import java.util.Queue;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

/**
 * Real-time WebSocket proxy bridging client live microphone streams with Sarvam Saaras Live STT.
 * Protects upstream API keys, enforces user authentication, buffers initial audio chunks, and saves session history.
 */
@Component
@Slf4j
public class LiveSttWebSocketHandler extends AbstractWebSocketHandler {

    private final WSTicketService wsTicketService;
    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public LiveSttWebSocketHandler(
            WSTicketService wsTicketService,
            JwtService jwtService,
            UserRepository userRepository) {
        this.wsTicketService = wsTicketService;
        this.jwtService = jwtService;
        this.userRepository = userRepository;
    }

    @Value("${sarvam.apiKey:}")
    private String sarvamApiKey;

    @Value("${sarvam.stt.live.url:wss://api.sarvam.ai/speech-to-text-realtime/ws}")
    private String sarvamLiveWsUrl;

    // Track active client live session states
    private final Map<String, LiveSessionContext> sessions = new ConcurrentHashMap<>();

    private static class LiveSessionContext {
        User user;
        WebSocketSession clientSession;
        WebSocketSession upstreamSession;
        volatile boolean upstreamConnecting = false;
        String language = "auto";
        String mode = "transcribe";
        long totalAudioBytes = 0;
        final StringBuilder finalTranscripts = new StringBuilder();
        final Queue<byte[]> pendingAudioQueue = new ConcurrentLinkedQueue<>();
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws Exception {
        String query = session.getUri() != null ? session.getUri().getQuery() : null;
        String username = resolveUsername(query);

        if (username == null) {
            log.warn("Unauthorized Live STT WebSocket handshake attempt from IP {}", session.getRemoteAddress());
            session.close(CloseStatus.NOT_ACCEPTABLE.withReason("Authentication required (ticket or token)"));
            return;
        }

        User user = userRepository.findByUsername(username).orElse(null);
        if (user == null || !user.isActive()) {
            session.close(CloseStatus.POLICY_VIOLATION.withReason("User account inactive"));
            return;
        }

        if (user.getPlanType() == null || user.getPlanType() == PlanType.FREE) {
            log.warn("User {} on FREE plan attempted Live STT session; gated to PRO+", username);
            session.close(CloseStatus.POLICY_VIOLATION.withReason("Live Transcription requires a Pro plan or higher"));
            return;
        }

        LiveSessionContext ctx = new LiveSessionContext();
        ctx.user = user;
        ctx.clientSession = session;

        String langParam = extractQueryParam(query, "language_code");
        if (langParam != null && !langParam.isBlank()) {
            ctx.language = normalizeLanguageCode(langParam);
        }
        String modeParam = extractQueryParam(query, "mode");
        if (modeParam != null && !modeParam.isBlank()) {
            ctx.mode = modeParam;
        }

        sessions.put(session.getId(), ctx);

        log.info("Live STT client connected: user={}, plan={}, lang={}, mode={}, sessionId={}",
                username, user.getPlanType(), ctx.language, ctx.mode, session.getId());

        // Notify client that proxy connection is established and awaiting config or audio
        session.sendMessage(new TextMessage("{\"type\": \"proxy.ready\", \"message\": \"SpeakIT Live STT ready\"}"));

        // If language and mode were provided in query, connect upstream immediately
        if (langParam != null || modeParam != null) {
            if ("translate".equalsIgnoreCase(ctx.mode) && user.getPlanType().getRank() < PlanType.PRO_PLUS.getRank()) {
                log.warn("User {} attempted Live Translation on {} plan; requires PRO_PLUS+", user.getUsername(), user.getPlanType());
                session.sendMessage(new TextMessage("{\"type\": \"error\", \"code\": \"PLAN_UPGRADE_REQUIRED\", \"message\": \"Live Translation requires Pro Plus or Enterprise plan.\"}"));
                return;
            }
            connectToSarvamUpstream(ctx);
        }
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage message) throws Exception {
        LiveSessionContext ctx = sessions.get(session.getId());
        if (ctx == null) return;

        String payload = message.getPayload();
        log.debug("Received text message from client {}: {}", session.getId(), payload);

        try {
            JsonNode node = objectMapper.readTree(payload);
            if (node.has("language_code")) {
                ctx.language = normalizeLanguageCode(node.get("language_code").asText("auto"));
            }
            if (node.has("mode")) {
                ctx.mode = node.get("mode").asText("transcribe");
            }

            if ("translate".equalsIgnoreCase(ctx.mode)) {
                if (ctx.user.getPlanType() == null || ctx.user.getPlanType().getRank() < PlanType.PRO_PLUS.getRank()) {
                    log.warn("User {} attempted Live Translation on {} plan; requires PRO_PLUS+",
                            ctx.user.getUsername(), ctx.user.getPlanType());
                    session.sendMessage(new TextMessage("{\"type\": \"error\", \"code\": \"PLAN_UPGRADE_REQUIRED\", \"message\": \"Live Translation requires Pro Plus or Enterprise plan.\"}"));
                    return;
                }
            }

            // Connect upstream to Sarvam WebSocket if not already connected
            if (ctx.upstreamSession == null || !ctx.upstreamSession.isOpen()) {
                connectToSarvamUpstream(ctx);
            } else if (node.has("event")) {
                // Forward explicit event payloads (e.g. config.update, speech_start, speech_end)
                ctx.upstreamSession.sendMessage(message);
            }
        } catch (Exception e) {
            log.error("Failed to parse/forward client text message for session {}: {}", session.getId(), e.getMessage());
            session.sendMessage(new TextMessage("{\"type\": \"error\", \"message\": \"" + e.getMessage() + "\"}"));
        }
    }

    @Override
    protected void handleBinaryMessage(WebSocketSession session, BinaryMessage message) throws Exception {
        LiveSessionContext ctx = sessions.get(session.getId());
        if (ctx == null) return;

        ByteBuffer byteBuffer = message.getPayload();
        byte[] bytes;
        if (byteBuffer.hasArray()) {
            bytes = byteBuffer.array();
        } else {
            bytes = new byte[byteBuffer.remaining()];
            byteBuffer.get(bytes);
        }

        ctx.totalAudioBytes += bytes.length;

        long maxBytes = getMaxAllowedAudioBytes(ctx.user.getPlanType());
        if (ctx.totalAudioBytes > maxBytes) {
            log.warn("Live STT session for user {} reached byte limit ({} bytes, plan {})",
                    ctx.user.getUsername(), ctx.totalAudioBytes, ctx.user.getPlanType());
            session.sendMessage(new TextMessage("{\"type\": \"session.limit_reached\", \"message\": \"Live session duration limit reached for your plan.\"}"));
            session.close(new CloseStatus(4000, "Session duration limit reached"));
            return;
        }

        // Sarvam realtime API requires {"event": "audio_input", "audio": "<base64>"}
        if (ctx.upstreamSession != null && ctx.upstreamSession.isOpen()) {
            String b64 = Base64.getEncoder().encodeToString(bytes);
            ctx.upstreamSession.sendMessage(new TextMessage("{\"event\":\"audio_input\",\"audio\":\"" + b64 + "\"}"));
        } else {
            // Buffer initial audio chunks while upstream connection is establishing (up to ~2.5s of audio)
            if (ctx.pendingAudioQueue.size() < 50) {
                ctx.pendingAudioQueue.offer(bytes);
            }
            if (!ctx.upstreamConnecting && (ctx.upstreamSession == null || !ctx.upstreamSession.isOpen())) {
                connectToSarvamUpstream(ctx);
            }
        }
    }

    private long getMaxAllowedAudioBytes(PlanType planType) {
        if (planType == null) return 0;
        int minutes = switch (planType) {
            case FREE -> 0;
            case PRO -> 10;
            case PRO_PLUS -> 30;
            case ENTERPRISE -> 120;
        };
        // 16kHz 16-bit mono PCM = 32,000 bytes/sec = 1,920,000 bytes/minute
        return (long) minutes * 60 * 32000L;
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) throws Exception {
        LiveSessionContext ctx = sessions.remove(session.getId());
        if (ctx != null) {
            log.info("Live STT client disconnected: user={}, audioBytes={}, status={}",
                    ctx.user.getUsername(), ctx.totalAudioBytes, status);

            if (ctx.upstreamSession != null && ctx.upstreamSession.isOpen()) {
                try {
                    ctx.upstreamSession.close();
                } catch (IOException ignored) {}
            }

            // Atomically increment the STT usage ledger immediately after each turn
            int turnChars = ctx.finalTranscripts.length();
            if (turnChars > 0 && ctx.user != null) {
                userRepository.incrementSttCharsUsed(ctx.user.getId(), turnChars, java.time.LocalDate.now().withDayOfMonth(1));
                log.info("Incremented STT usage ledger immediately after turn: user={}, chars={}", ctx.user.getUsername(), turnChars);
            }

            // Note: Full session history persistence is handled by POST /api/stt/live/session
            // once the user finishes their session, keeping a single cohesive history entry.
            log.debug("Live STT session closed for user {}: totalBytes={}", ctx.user.getUsername(), ctx.totalAudioBytes);
        }
    }

    private synchronized void connectToSarvamUpstream(LiveSessionContext ctx) {
        if (ctx.upstreamConnecting || (ctx.upstreamSession != null && ctx.upstreamSession.isOpen())) {
            return;
        }

        if (sarvamApiKey == null || sarvamApiKey.isBlank()) {
            log.warn("Sarvam API key not configured; running in mock/offline mode");
            try {
                ctx.clientSession.sendMessage(new TextMessage("{\"type\": \"transcript.partial\", \"text\": \"Live listening active (simulation)...\"}"));
            } catch (IOException ignored) {}
            return;
        }

        ctx.upstreamConnecting = true;

        try {
            StandardWebSocketClient client = new StandardWebSocketClient();
            WebSocketHttpHeaders headers = new WebSocketHttpHeaders();
            String cleanApiKey = sarvamApiKey.trim();
            headers.set("api-subscription-key", cleanApiKey);
            headers.setSecWebSocketProtocol(java.util.List.of("api-subscription-key." + cleanApiKey));

            String lang = (ctx.language != null && !ctx.language.isBlank()) ? ctx.language : "auto";
            String mode = (ctx.mode != null && !ctx.mode.isBlank()) ? ctx.mode : "transcribe";
            String model = "saaras:v3-realtime";

            StringBuilder sb = new StringBuilder(sarvamLiveWsUrl);
            sb.append(sarvamLiveWsUrl.contains("?") ? "&" : "?");
            sb.append("language_code=").append(URLEncoder.encode(lang, StandardCharsets.UTF_8));
            sb.append("&model=").append(URLEncoder.encode(model, StandardCharsets.UTF_8));
            sb.append("&mode=").append(URLEncoder.encode(mode, StandardCharsets.UTF_8));

            URI uri = URI.create(sb.toString());
            log.info("Connecting to Sarvam live STT upstream for user {}: {}", ctx.user.getUsername(), uri);

            client.execute(new WebSocketHandler() {
                @Override
                public void afterConnectionEstablished(WebSocketSession upstream) throws Exception {
                    ctx.upstreamSession = upstream;
                    ctx.upstreamConnecting = false;
                    log.info("Connected to Sarvam live STT upstream for user {}", ctx.user.getUsername());

                    // Flush buffered initial audio chunks immediately
                    byte[] chunk;
                    while ((chunk = ctx.pendingAudioQueue.poll()) != null) {
                        String b64 = Base64.getEncoder().encodeToString(chunk);
                        upstream.sendMessage(new TextMessage("{\"event\":\"audio_input\",\"audio\":\"" + b64 + "\"}"));
                    }
                }

                @Override
                public void handleMessage(WebSocketSession upstream, WebSocketMessage<?> message) throws Exception {
                    if (!ctx.clientSession.isOpen()) return;

                    if (message instanceof TextMessage textMessage) {
                        String payload = textMessage.getPayload();
                        log.debug("Received from Sarvam upstream: {}", payload);

                        try {
                            JsonNode node = objectMapper.readTree(payload);
                            String eventType = node.path("type").asText(node.path("event").asText(""));

                            String extractedText = "";
                            if (node.hasNonNull("text")) {
                                extractedText = node.get("text").asText();
                            } else if (node.hasNonNull("transcript")) {
                                extractedText = node.get("transcript").asText();
                            } else if (node.has("data")) {
                                JsonNode data = node.get("data");
                                if (data.hasNonNull("transcript")) {
                                    extractedText = data.get("transcript").asText();
                                } else if (data.hasNonNull("text")) {
                                    extractedText = data.get("text").asText();
                                }
                            }

                            boolean isPartial = eventType.contains("partial") || "transcript.partial".equalsIgnoreCase(eventType);
                            boolean isFinal = eventType.contains("final") || "transcript.final".equalsIgnoreCase(eventType);

                            if (isFinal && !extractedText.isBlank()) {
                                if (ctx.finalTranscripts.length() > 0) ctx.finalTranscripts.append(" ");
                                ctx.finalTranscripts.append(extractedText.trim());
                            }

                            // Construct clean normalized JSON event for the client
                            Map<String, Object> responseMap = new HashMap<>();
                            if (isFinal) {
                                responseMap.put("type", "transcript.final");
                                responseMap.put("is_final", true);
                            } else if (isPartial) {
                                responseMap.put("type", "transcript.partial");
                                responseMap.put("is_final", false);
                            } else {
                                responseMap.put("type", eventType.isEmpty() ? "transcript.update" : eventType);
                            }
                            responseMap.put("text", extractedText);
                            if (node.has("language_code")) {
                                responseMap.put("language_code", node.get("language_code").asText());
                            }

                            String normalizedJson = objectMapper.writeValueAsString(responseMap);
                            ctx.clientSession.sendMessage(new TextMessage(normalizedJson));
                        } catch (Exception e) {
                            log.warn("Error processing upstream message, forwarding raw: {}", e.getMessage());
                            ctx.clientSession.sendMessage(message);
                        }
                    } else {
                        ctx.clientSession.sendMessage(message);
                    }
                }

                @Override
                public void handleTransportError(WebSocketSession upstream, Throwable exception) throws Exception {
                    log.error("Sarvam upstream WS error: {}", exception.getMessage());
                    ctx.upstreamConnecting = false;
                    if (ctx.clientSession.isOpen()) {
                        ctx.clientSession.sendMessage(new TextMessage("{\"type\": \"error\", \"message\": \"Upstream speech engine error\"}"));
                    }
                }

                @Override
                public void afterConnectionClosed(WebSocketSession upstream, CloseStatus closeStatus) throws Exception {
                    log.info("Sarvam upstream WS closed: code={}, reason={}", closeStatus.getCode(), closeStatus.getReason());
                    ctx.upstreamConnecting = false;
                    if (ctx.clientSession.isOpen() && closeStatus.getCode() != CloseStatus.NORMAL.getCode()) {
                        String reasonClean = closeStatus.getReason() != null ? closeStatus.getReason().replace("\"", "'") : "";
                        ctx.clientSession.sendMessage(new TextMessage("{\"type\": \"upstream.closed\", \"code\": " + closeStatus.getCode() + ", \"reason\": \"" + reasonClean + "\"}"));
                    }
                }

                @Override
                public boolean supportsPartialMessages() {
                    return false;
                }
            }, headers, uri);
        } catch (Exception e) {
            ctx.upstreamConnecting = false;
            log.error("Failed to connect to Sarvam upstream WebSocket: {}", e.getMessage());
            try {
                ctx.clientSession.sendMessage(new TextMessage("{\"type\": \"error\", \"message\": \"Could not connect to Sarvam live service\"}"));
            } catch (IOException ignored) {}
        }
    }

    private String normalizeLanguageCode(String raw) {
        if (raw == null || raw.isBlank() || "auto".equalsIgnoreCase(raw)) {
            return "auto";
        }
        String trimmed = raw.trim();
        if (trimmed.contains("-")) {
            return trimmed;
        }
        return switch (trimmed.toLowerCase()) {
            case "en" -> "en-IN";
            case "hi" -> "hi-IN";
            case "bn" -> "bn-IN";
            case "ta" -> "ta-IN";
            case "te" -> "te-IN";
            case "mr" -> "mr-IN";
            case "gu" -> "gu-IN";
            case "kn" -> "kn-IN";
            case "ml" -> "ml-IN";
            case "pa" -> "pa-IN";
            case "od", "or" -> "od-IN";
            case "ur" -> "ur-IN";
            case "as" -> "as-IN";
            default -> trimmed + "-IN";
        };
    }

    private String extractQueryParam(String query, String paramName) {
        if (query == null) return null;
        for (String param : query.split("&")) {
            int idx = param.indexOf('=');
            if (idx > 0 && param.substring(0, idx).equals(paramName)) {
                return param.substring(idx + 1);
            }
        }
        return null;
    }

    private String resolveUsername(String query) {
        if (query == null) return null;
        for (String param : query.split("&")) {
            if (param.startsWith("ticket=")) {
                String ticket = param.substring(7);
                String username = wsTicketService.consumeTicket(ticket);
                if (username != null) return username;
            } else if (param.startsWith("token=")) {
                String token = param.substring(6);
                try {
                    return jwtService.extractUsername(token);
                } catch (Exception ignored) {}
            }
        }
        return null;
    }
}
