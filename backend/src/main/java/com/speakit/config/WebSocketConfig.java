package com.speakit.config;

import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

import java.util.Arrays;

@Configuration
@EnableWebSocket
@RequiredArgsConstructor
public class WebSocketConfig implements WebSocketConfigurer {

    private final LogoutWebSocketHandler logoutWebSocketHandler;
    private final com.speakit.stt.websocket.LiveSttWebSocketHandler liveSttWebSocketHandler;
    private final com.speakit.stt.websocket.ElevenLabsLiveTtsWebSocketHandler elevenLabsLiveTtsWebSocketHandler;

    @Value("${cors.allowed-origins:http://localhost:4200,http://127.0.0.1:4200}")
    private String allowedOrigins;

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        String[] patterns = Arrays.stream(allowedOrigins.split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .toArray(String[]::new);
        if (patterns.length == 0) {
            patterns = new String[]{"http://localhost:4200", "http://127.0.0.1:4200"};
        }

        registry.addHandler(logoutWebSocketHandler, "/ws/logout")
                .setAllowedOriginPatterns(patterns);

        registry.addHandler(liveSttWebSocketHandler, "/ws/live-stt")
                .setAllowedOriginPatterns(patterns);

        // Phase 4: Live Voice Bridge — ElevenLabs Streaming TTS proxy
        registry.addHandler(elevenLabsLiveTtsWebSocketHandler, "/ws/live-tts")
                .setAllowedOriginPatterns(patterns);
    }

    public void notifyLogout(String username) {
        logoutWebSocketHandler.notifyLogout(username);
    }
}
