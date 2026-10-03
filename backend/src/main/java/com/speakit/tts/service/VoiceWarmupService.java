package com.speakit.tts.service;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.context.event.ApplicationReadyEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

/**
 * Proactively warms up external TTS provider voice caches (Polly, ElevenLabs)
 * upon application startup to ensure zero latency on the first client request.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class VoiceWarmupService {

    private final PollyService pollyService;
    private final ElevenLabsService elevenLabsService;

    @EventListener(ApplicationReadyEvent.class)
    public void warmupVoices() {
        CompletableFuture.runAsync(() -> {
            try {
                long t0 = System.currentTimeMillis();
                CompletableFuture<Void> pollyWarmup = CompletableFuture.runAsync(() -> {
                    try {
                        pollyService.getRawAvailableVoices();
                    } catch (Exception e) {
                        log.debug("Polly warmup notice: {}", e.getMessage());
                    }
                });
                CompletableFuture<Void> elevenWarmup = CompletableFuture.runAsync(() -> {
                    try {
                        elevenLabsService.getAvailableVoices();
                    } catch (Exception e) {
                        log.debug("ElevenLabs warmup notice: {}", e.getMessage());
                    }
                });
                CompletableFuture.allOf(pollyWarmup, elevenWarmup).join();
                log.info("TTS voice caches warmed up successfully in {}ms", (System.currentTimeMillis() - t0));
            } catch (Exception e) {
                log.warn("Voice cache warmup failed: {}", e.getMessage());
            }
        });
    }
}
