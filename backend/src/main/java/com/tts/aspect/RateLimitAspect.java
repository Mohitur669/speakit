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
import org.springframework.web.context.request.RequestContextHolder;
import org.springframework.web.context.request.ServletRequestAttributes;

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

    @Around("@annotation(com.tts.aspect.RateLimited)")
    public Object enforceRateLimit(ProceedingJoinPoint joinPoint) throws Throwable {
        HttpServletRequest currentRequest = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
        
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        RateLimited rateLimited = signature.getMethod().getAnnotation(RateLimited.class);
        RateLimitAction action = rateLimited.action();

        if (action == RateLimitAction.PUBLIC) {
            return handlePublicMultiLimit(joinPoint, currentRequest);
        }

        String bucketKey = generateBucketKey(action, currentRequest, joinPoint.getArgs());
        return checkBucket(bucketKey, action, joinPoint);
    }

    private Object handlePublicMultiLimit(ProceedingJoinPoint joinPoint, HttpServletRequest req) throws Throwable {
        String clientIp = extractRealIp(req);
        
        // Signal 1: IP-based limiting (The standard shield)
        checkBucket("PUB_IP_" + clientIp, RateLimitAction.PUBLIC, null);

        // Signal 2: Identity-based limiting (Email)
        for (Object arg : joinPoint.getArgs()) {
            if (arg instanceof com.tts.dto.ContactRequest) {
                String email = ((com.tts.dto.ContactRequest) arg).getEmail();
                if (email != null && !email.isEmpty()) {
                    String emailHash = hashString(email.toLowerCase().trim());
                    checkBucket("PUB_EMAIL_" + emailHash, RateLimitAction.PUBLIC, null);
                }
            }
        }

        return joinPoint.proceed();
    }

    private Object checkBucket(String key, RateLimitAction action, ProceedingJoinPoint joinPoint) throws Throwable {
        Bucket bucket = rateLimitBuckets.computeIfAbsent(key, k -> createBucketForAction(action));
        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);

        if (probe.isConsumed()) {
            return joinPoint != null ? joinPoint.proceed() : null;
        } else {
            long wait = probe.getNanosToWaitForRefill() / 1_000_000_000;
            log.warn("Rate limit hit for key: {} (Action: {})", key, action);
            throw new RateLimitExceededException("Too many requests. Please try again later.", wait);
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
            case LIVE_PARAM -> rateLimitConfig.createLiveParamBucket();
        };
    }

    /**
     * Generates a unique rate-limiting key based on layered signals to prevent bypasses.
     */
    private String generateBucketKey(RateLimitAction action, HttpServletRequest req, Object[] args) {
        String clientIp = extractRealIp(req);

        return switch (action) {
            case LIVE_PARAM -> "LIVE_PARAM_" + clientIp;
            case TTS -> {
                // For expensive operations, bind the limit to the authenticated User ID.
                Long userId = (Long) req.getAttribute("userId");
                if (userId != null) {
                    yield "TTS_USER_" + userId;
                }
                yield "TTS_IP_" + clientIp;
            }
            case AUTH -> {
                String userAgent = req.getHeader("User-Agent");
                String fingerprint = hashString(clientIp + (userAgent != null ? userAgent : ""));
                yield "AUTH_" + fingerprint;
            }
            case PUBLIC -> {
                // Defense-in-Depth: If it's a contact form, we also limit by the email provided in the body
                // to prevent one email from being used across 10,000 IPs.
                String emailSuffix = "";
                for (Object arg : args) {
                    if (arg instanceof com.tts.dto.ContactRequest) {
                        String email = ((com.tts.dto.ContactRequest) arg).getEmail();
                        if (email != null && !email.isEmpty()) {
                            emailSuffix = "_EMAIL_" + hashString(email.toLowerCase().trim());
                        }
                    }
                }
                yield "PUBLIC_" + clientIp + emailSuffix;
            }
        };
    }

    /**
     * Extracts the client IP from the request.
     * Security: Relies on server.forward-headers-strategy=FRAMEWORK 
     * in application.properties to handle trusted proxies (Cloudflare/Render).
     */
    private String extractRealIp(HttpServletRequest request) {
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
