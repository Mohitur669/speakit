package com.speakit.config;

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
    private final Map<String, Set<WebSocketSession>> userSessions = new ConcurrentHashMap<>();

    public LogoutWebSocketHandler(WSTicketService wsTicketService) {
        this.wsTicketService = wsTicketService;
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
        if (query != null && query.startsWith("ticket=")) {
            String ticket = query.substring(7);
            try {
                String username = wsTicketService.consumeTicket(ticket);

                if (username != null) {
                    userSessions.computeIfAbsent(username, k -> new CopyOnWriteArraySet<>()).add(session);
                    log.info("WS Connected: {} (Total sessions: {})", username, userSessions.get(username).size());
                } else {
                    session.close(CloseStatus.BAD_DATA);
                }
            } catch (Exception e) {
                try {
                    session.close(CloseStatus.SERVER_ERROR);
                } catch (IOException ignored) {}
            }
        }
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
