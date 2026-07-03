package com.speakit.tts.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestClient;

@Service
@RequiredArgsConstructor
@Slf4j
public class KeepAliveService {

    private final RestClient restClient = RestClient.create();
    private final SystemParameterService systemParameterService;

    @Value("${auth.keep-alive-url:}")
    private String externalUrl;

    /**
     * Pings the application at a dynamic interval to prevent Render spin-down.
     */
    @Scheduled(fixedRateString = "${auth.keep-alive-interval-ms}")
    public void keepAlive() {
        boolean enabled = Boolean.parseBoolean(systemParameterService.getLiveParameter("KEEP_ALIVE_ENABLED", "true"));
        if (!enabled) {
            log.info("Keep-alive self-ping is disabled dynamically via system parameters.");
            return;
        }

        String targetUrl = systemParameterService.getCachedParameter("SELF_PING_URL", externalUrl);
        if (targetUrl == null || targetUrl.isEmpty()) {
            log.info("Keep-alive skipped: SELF_PING_URL and RENDER_EXTERNAL_URL are not set.");
            return;
        }

        try {
            String pingUrl = targetUrl + "/api/auth/ping";
            log.info("Sending keep-alive ping to: {}", pingUrl);
            restClient.get()
                    .uri(pingUrl)
                    .retrieve()
                    .toBodilessEntity();
        } catch (Exception e) {
            log.warn("Keep-alive ping failed (this is expected if the app is already spinning down): {}",
                    e.getMessage());
        }
    }
}
