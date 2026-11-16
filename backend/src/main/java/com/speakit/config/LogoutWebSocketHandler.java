package com.speakit.config;

import com.speakit.security.JwtService;
import com.speakit.tts.service.WSTicketService;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

@Component
@Slf4j
public class LogoutWebSocketHandler extends TextWebSocketHandler {

    private final WSTicketService wsTicketService;
    private final JwtService jwtService;
    private final Map<String, Set<WebSocketSession>> userSessions = new ConcurrentHashMap<>();

    public LogoutWebSocketHandler(WSTicketService wsTicketService, JwtService jwtService) {
        this.wsTicketService = wsTicketService;
        this.jwtService = jwtService;
    }

    public void notifyLogout(String username) {
        Set<WebSocketSession> sessions = userSessions.get(username);
        if (sessions != null) {
            sessions.forEach(session -> {
                if (session.isOpen()) {
                    try {
                        session.sendMessage(new TextMessage("LOGOUT"));
                    } catch (IOException e) {
                        log.error("Failed to send WS message: {}", e.getMessage());
                    }
                }
            });
        }
    }

    public Map<String, Set<WebSocketSession>> getUserSessions() {
        return userSessions;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) throws IOException {
        String query = session.getUri() != null ? session.getUri().getQuery() : null;
        String username = resolveUsername(query);

        if (username != null) {
            userSessions.computeIfAbsent(username, k -> new CopyOnWriteArraySet<>()).add(session);
            log.info("WS Connected: {} (Total sessions: {})", username, userSessions.get(username).size());
        } else {
            log.warn("Unauthorized Logout WebSocket handshake attempt from IP {}", session.getRemoteAddress());
            session.close(CloseStatus.POLICY_VIOLATION.withReason("Authentication required (valid ticket)"));
        }
    }

    private String resolveUsername(String query) {
        if (query == null) return null;
        for (String param : query.split("&")) {
            if (param.startsWith("ticket=")) {
                String ticket = param.substring(7);
                try {
                    return wsTicketService.consumeTicket(ticket);
                } catch (Exception e) {
                    log.error("Error validating WebSocket ticket: {}", e.getMessage());
                }
            } else if (param.startsWith("token=")) {
                String token = param.substring(6);
                try {
                    return jwtService.extractUsername(token);
                } catch (Exception ignored) {}
            }
        }
        return null;
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        userSessions.forEach((username, sessions) -> {
            if (sessions.remove(session)) {
                log.info("WS Disconnected: {}", username);
            }
        });
    }
}
