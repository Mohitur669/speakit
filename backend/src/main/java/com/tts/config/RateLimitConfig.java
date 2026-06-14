package com.tts.config;

import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import java.time.Duration;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Enterprise Rate Limiting Configuration.
 * 
 * Provides distinct bucket configurations based on endpoint sensitivity.
 * - AUTH: Highly restrictive to prevent credential stuffing and brute force.
 * - TTS: Cost-protected bounds for AWS Polly usage.
 * - PUBLIC: Standard sliding window for generic API scraping protection.
 * 
 * Scalability Note: Currently uses ConcurrentHashMap for single-node deployment.
 * For horizontal scaling (multi-instance), this should be migrated to 
 * Bucket4j-Redis or Bucket4j-Hazelcast using JCache.
 */
@Configuration
public class RateLimitConfig {

    // Default Fallbacks
    @Value("${rate-limit.capacity:100}")
    private long defaultCapacity;

    @Value("${rate-limit.refill-tokens:100}")
    private long defaultRefillTokens;

    @Value("${rate-limit.refill-duration-minutes:1}")
    private long defaultRefillDurationMinutes;

    @Value("${rate-limit.live-param.capacity:10}")
    private long liveParamCapacity;

    @Bean
    public ConcurrentHashMap<String, Bucket> rateLimitBuckets() {
        return new ConcurrentHashMap<>();
    }

    /**
     * Strict configuration for authentication endpoints.
     * Prevents brute force and credential stuffing.
     * Uses a fraction of the default capacity for higher security.
     */
    public Bucket createAuthBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(Math.max(3, defaultCapacity / 2))
                        .refillIntervally(Math.max(2, defaultRefillTokens / 2), Duration.ofMinutes(defaultRefillDurationMinutes))
                        .build())
                .build();
    }

    /**
     * Configuration for expensive AWS Polly operations.
     * Uses dynamic values from environment/application.properties.
     */
    public Bucket createTtsBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(defaultCapacity)
                        .refillIntervally(defaultRefillTokens, Duration.ofMinutes(defaultRefillDurationMinutes))
                        .build())
                .build();
    }

    public Bucket createLiveParamBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(liveParamCapacity)
                        .refillIntervally(liveParamCapacity, Duration.ofMinutes(1))
                        .build())
                .build();
    }

    /**
     * General configuration for public endpoints (like contact forms).
     */
    public Bucket createPublicBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(defaultCapacity)
                        .refillIntervally(defaultRefillTokens, Duration.ofMinutes(defaultRefillDurationMinutes))
                        .build())
                .build();
    }

    /**
     * Highly restricted bucket for health checks.
     * Designed to allow 1 internal ping every 14 minutes for Render free sleep prevention,
     * while blocking external flooding.
     */
    public Bucket createPingBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(3) // Allow small burst
                        .refillIntervally(1, Duration.ofMinutes(10)) // 1 token every 10 mins
                        .build())
                .build();
    }

    /**
     * Configuration for Speech-to-Text operations.
     * Restrictive to prevent cost-exhaustion from large file processing.
     */
    public Bucket createSttBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(5) // Allow small burst of transcriptions
                        .refillIntervally(5, Duration.ofHours(1)) // 5 tokens per hour
                        .build())
                .build();
    }
}
