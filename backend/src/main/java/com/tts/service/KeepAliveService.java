package com.tts.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

@Service
@Slf4j
public class KeepAliveService {

    private final RestTemplate restTemplate = new RestTemplate();

    @Value("${auth.keep-alive-url:}")
    private String externalUrl;

    /**
     * Pings the application at a dynamic interval to prevent Render spin-down.
     * Uses fixedRateString to allow dynamic configuration from properties.
     */
    @Scheduled(fixedRateString = "${auth.keep-alive-interval-ms}")
    public void keepAlive() {
        if (externalUrl == null || externalUrl.isEmpty()) {
            log.info("Keep-alive skipped: RENDER_EXTERNAL_URL (auth.keep-alive-url) is not set.");
            return;
        }

        try {
            String pingUrl = externalUrl + "/api/auth/ping";
            log.info("Sending keep-alive ping to: {}", pingUrl);
            restTemplate.getForObject(pingUrl, Void.class);
        } catch (Exception e) {
            log.warn("Keep-alive ping failed (this is expected if the app is already spinning down): {}", e.getMessage());
        }
    }
}
