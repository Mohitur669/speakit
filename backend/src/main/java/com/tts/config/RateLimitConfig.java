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

    @Bean
    public ConcurrentHashMap<String, Bucket> rateLimitBuckets() {
        return new ConcurrentHashMap<>();
    }

    /**
     * Strict configuration for authentication endpoints.
     * Prevents brute force and credential stuffing.
     * Allows 5 attempts per minute.
     */
    public Bucket createAuthBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(5)
                        .refillIntervally(5, Duration.ofMinutes(1))
                        .build())
                .build();
    }

    /**
     * Configuration for expensive AWS Polly operations.
     * Provides a larger initial burst but throttles sustained aggressive usage.
     * Allows 30 requests per minute burst, refilling at 10 per minute.
     */
    public Bucket createTtsBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(30)
                        .refillIntervally(10, Duration.ofMinutes(1))
                        .build())
                .build();
    }

    /**
     * General configuration for public endpoints (like contact forms).
     * Uses environment variables with sensible defaults.
     */
    public Bucket createPublicBucket() {
        return Bucket.builder()
                .addLimit(Bandwidth.builder()
                        .capacity(defaultCapacity)
                        .refillIntervally(defaultRefillTokens, Duration.ofMinutes(defaultRefillDurationMinutes))
                        .build())
                .build();
    }
}
