package com.tts.config;

import com.tts.repository.UserRepository;
import com.tts.entity.User;
import com.tts.security.JwtService;
import lombok.RequiredArgsConstructor;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.CopyOnWriteArraySet;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final Map<String, Set<WebSocketSession>> userSessions = new ConcurrentHashMap<>();

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(new LogoutWebSocketHandler(), "/ws/logout")
                .setAllowedOriginPatterns("*");
    }

    public void notifyLogout(String username) {
        Set<WebSocketSession> sessions = userSessions.get(username);
        if (sessions != null) {
            sessions.forEach(session -> {
                if (session.isOpen()) {
                    try {
                        session.sendMessage(new TextMessage("LOGOUT"));
                    } catch (IOException e) {
                        System.err.println("Failed to send WS message: " + e.getMessage());
                    }
                }
            });
        }
    }

    private class LogoutWebSocketHandler extends TextWebSocketHandler {
        @Override
        public void afterConnectionEstablished(WebSocketSession session) throws IOException {
            String query = session.getUri().getQuery();
            if (query != null && query.startsWith("token=")) {
                String token = query.substring(6);
                try {
                    String username = jwtService.extractUsername(token);
                    Long tokenVersion = jwtService.extractSessionVersion(token);
                    
                    if (username != null && tokenVersion != null) {
                        User user = userRepository.findByUsername(username).orElse(null);
                        
                        // Check if session is already invalid on connection (e.g., wake-up scenario)
                        if (user != null && tokenVersion.longValue() != user.getSessionVersion().longValue()) {
                            session.sendMessage(new TextMessage("LOGOUT"));
                            session.close(CloseStatus.NORMAL);
                            return;
                        }

                        if (username != null) {
                            userSessions.computeIfAbsent(username, k -> new CopyOnWriteArraySet<>()).add(session);
                            System.out.println("WS Connected: " + username + " (Total sessions: " + userSessions.get(username).size() + ")");
                        }
                    }
                } catch (Exception e) {
                    try {
                        session.close(CloseStatus.BAD_DATA);
                    } catch (IOException ignored) {}
                }
            }
        }

        @Override
        public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
            userSessions.forEach((username, sessions) -> {
                if (sessions.remove(session)) {
                    System.out.println("WS Disconnected: " + username);
                }
            });
        }
    }
}
