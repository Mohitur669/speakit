package com.tts.aspect;

import com.tts.config.RateLimitConfig;
import com.tts.exception.RateLimitExceededException;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.ConsumptionProbe;
import jakarta.servlet.http.HttpServletRequest;
import lombok.extern.slf4j.Slf4j;
import org.aspectj.lang.ProceedingJoinPoint;
import org.aspectj.lang.annotation.Around;
import org.aspectj.lang.annotation.Aspect;
import org.aspectj.lang.reflect.MethodSignature;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Advanced Multi-Layered Rate Limiting Aspect.
 * 
 * Provides defense-in-depth API protection by analyzing multiple signals
 * (IP, Proxy Headers, User-Agent, JWT identity) to prevent abuse vectors 
 * like Botnets, NAT rotation, and Cost-Exhaustion attacks.
 */
@Aspect
@Component
@Slf4j
public class RateLimitAspect {

    @Autowired
    private ConcurrentHashMap<String, Bucket> rateLimitBuckets;

    @Autowired
    private RateLimitConfig rateLimitConfig;

    @Autowired
    private HttpServletRequest request;

    @Around("@annotation(com.tts.aspect.RateLimited)")
    public Object enforceRateLimit(ProceedingJoinPoint joinPoint) throws Throwable {
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        RateLimited rateLimited = signature.getMethod().getAnnotation(RateLimited.class);
        RateLimitAction action = rateLimited.action();

        String bucketKey = generateBucketKey(action, request);
        Bucket bucket = rateLimitBuckets.computeIfAbsent(bucketKey, k -> createBucketForAction(action));

        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);

        if (probe.isConsumed()) {
            return joinPoint.proceed();
        } else {
            long waitForRefillSeconds = probe.getNanosToWaitForRefill() / 1_000_000_000;
            log.warn("Rate limit exceeded for key: {} (Action: {}). Must wait {} seconds.", bucketKey, action, waitForRefillSeconds);
            throw new RateLimitExceededException("Too many requests. Please try again later.", waitForRefillSeconds);
        }
    }

    /**
     * Determines the correct bucket configuration based on the endpoint's sensitivity.
     */
    private Bucket createBucketForAction(RateLimitAction action) {
        return switch (action) {
            case AUTH -> rateLimitConfig.createAuthBucket();
            case TTS -> rateLimitConfig.createTtsBucket();
            case PUBLIC -> rateLimitConfig.createPublicBucket();
        };
    }

    /**
     * Generates a unique rate-limiting key based on layered signals to prevent bypasses.
     */
    private String generateBucketKey(RateLimitAction action, HttpServletRequest request) {
        String clientIp = extractRealIp(request);

        return switch (action) {
            case TTS -> {
                // For expensive operations, bind the limit to the authenticated User ID if possible
                Long userId = (Long) request.getAttribute("userId");
                yield (userId != null) ? "TTS_USER_" + userId : "TTS_IP_" + clientIp;
            }
            case AUTH -> {
                // For Auth (Login/Register), combine IP and User-Agent to stop basic botnet rotation
                String userAgent = request.getHeader("User-Agent");
                String fingerprint = hashString(clientIp + (userAgent != null ? userAgent : ""));
                yield "AUTH_" + fingerprint;
            }
            case PUBLIC -> "PUBLIC_" + clientIp;
        };
    }

    /**
     * Extracts the real client IP, strictly prioritizing trusted proxy headers.
     * Prevents bypassing via basic IP spoofing.
     */
    private String extractRealIp(HttpServletRequest request) {
        // Cloudflare awareness (Strongest signal if using CF proxy)
        String cfIp = request.getHeader("CF-Connecting-IP");
        if (cfIp != null && !cfIp.isEmpty()) {
            return cfIp;
        }

        // Standard load balancer awareness
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim(); // Take the true origin, ignoring intermediate proxies
        }

        return request.getRemoteAddr();
    }

    /**
     * Utility to generate a safe device/session fingerprint hash.
     */
    private String hashString(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hash);
        } catch (NoSuchAlgorithmException e) {
            return String.valueOf(input.hashCode()); // Fallback
        }
    }
}
