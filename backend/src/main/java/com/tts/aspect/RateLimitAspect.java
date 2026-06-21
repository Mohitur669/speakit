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
        HttpServletRequest req = ((ServletRequestAttributes) RequestContextHolder.currentRequestAttributes()).getRequest();
        
        MethodSignature signature = (MethodSignature) joinPoint.getSignature();
        RateLimited rateLimited = signature.getMethod().getAnnotation(RateLimited.class);
        RateLimitAction action = rateLimited.action();

        String clientIp = extractRealIp(req);
        String deviceFp = extractDeviceFingerprint(req);

        switch (action) {
            case PUBLIC -> {
                // Layer 1: IP-based limiting (The standard shield)
                checkBucket("PUB_IP_" + clientIp, RateLimitAction.PUBLIC);
                
                // Layer 1.5: Device fingerprint limiting (stops IP rotation enumeration)
                checkBucket("PUB_DEV_" + deviceFp, RateLimitAction.PUBLIC);

                // Layer 2: Identity-based limiting (Email)
                for (Object arg : joinPoint.getArgs()) {
                    if (arg instanceof com.tts.dto.ContactRequest) {
                        String email = ((com.tts.dto.ContactRequest) arg).getEmail();
                        if (email != null && !email.isEmpty()) {
                            String emailHash = hashString(email.toLowerCase().trim());
                            checkBucket("PUB_EMAIL_" + emailHash, RateLimitAction.PUBLIC);
                        }
                    }
                }
            }
            case AUTH -> {
                // Layer 1: IP-based limiting (brute force protection per IP)
                checkBucket("AUTH_IP_" + clientIp, RateLimitAction.AUTH);

                // Layer 1.5: Device fingerprint limiting (stops IP rotation scripts)
                checkBucket("AUTH_DEV_" + deviceFp, RateLimitAction.AUTH);

                // Layer 2: User-based limiting (prevent credential stuffing / brute forcing rotating IPs on a single user)
                for (Object arg : joinPoint.getArgs()) {
                    if (arg instanceof com.tts.dto.AuthRequest) {
                        com.tts.dto.AuthRequest authReq = (com.tts.dto.AuthRequest) arg;
                        String identifier = null;
                        if (authReq.getEmail() != null && !authReq.getEmail().isEmpty()) {
                            identifier = authReq.getEmail().toLowerCase().trim();
                        } else if (authReq.getUsername() != null && !authReq.getUsername().isEmpty()) {
                            identifier = authReq.getUsername().toLowerCase().trim();
                        } else if (authReq.getPhoneNumber() != null && !authReq.getPhoneNumber().isEmpty()) {
                            identifier = authReq.getPhoneNumber().trim();
                        }
                        if (identifier != null) {
                            String idHash = hashString(identifier);
                            checkBucket("AUTH_USER_" + idHash, RateLimitAction.AUTH);
                        }
                    }
                }
            }
            case OTP_VERIFY -> {
                // Layer 1: IP-based limiting (prevent a single IP from checking many codes)
                checkBucket("OTP_VERIFY_IP_" + clientIp, RateLimitAction.OTP_VERIFY);

                // Layer 1.5: Device fingerprint limiting (stops IP rotation brute forcing)
                checkBucket("OTP_VERIFY_DEV_" + deviceFp, RateLimitAction.OTP_VERIFY);

                // Layer 2: Identity-based limiting (prevent rotating IPs from brute-forcing a single user's OTP)
                for (Object arg : joinPoint.getArgs()) {
                    if (arg instanceof com.tts.dto.VerifyEmailRequest) {
                        String email = ((com.tts.dto.VerifyEmailRequest) arg).getEmail();
                        if (email != null && !email.isEmpty()) {
                            String emailHash = hashString(email.toLowerCase().trim());
                            checkBucket("OTP_VERIFY_EMAIL_" + emailHash, RateLimitAction.OTP_VERIFY);
                        }
                    } else if (arg instanceof com.tts.dto.VerifyEmailChangeRequest) {
                        java.security.Principal principal = req.getUserPrincipal();
                        if (principal != null) {
                            String userHash = hashString(principal.getName().toLowerCase().trim());
                            checkBucket("OTP_VERIFY_USER_" + userHash, RateLimitAction.OTP_VERIFY);
                        }
                    }
                }
            }
            case OTP_RESEND -> {
                // Layer 1: IP-based limiting (prevent a single IP from triggering resends)
                checkBucket("OTP_RESEND_IP_" + clientIp, RateLimitAction.OTP_RESEND);

                // Layer 1.5: Device fingerprint limiting (stops IP rotation abuse)
                checkBucket("OTP_RESEND_DEV_" + deviceFp, RateLimitAction.OTP_RESEND);

                // Layer 2: Identity-based limiting (prevent IP-rotation from mail-bombing a single target email)
                for (Object arg : joinPoint.getArgs()) {
                    if (arg instanceof com.tts.dto.ResendOtpRequest) {
                        String email = ((com.tts.dto.ResendOtpRequest) arg).getEmail();
                        if (email != null && !email.isEmpty()) {
                            String emailHash = hashString(email.toLowerCase().trim());
                            checkBucket("OTP_RESEND_EMAIL_" + emailHash, RateLimitAction.OTP_RESEND);
                        }
                    }
                }
            }
            case PASSWORD_RESET -> {
                // Layer 1: IP-based limiting
                checkBucket("PASSWORD_RESET_IP_" + clientIp, RateLimitAction.PASSWORD_RESET);

                // Layer 1.5: Device fingerprint limiting (stops IP rotation abuse)
                checkBucket("PASSWORD_RESET_DEV_" + deviceFp, RateLimitAction.PASSWORD_RESET);

                // Layer 2: Identity-based limiting (prevent IP-rotation from mail-bombing password reset requests to one user)
                for (Object arg : joinPoint.getArgs()) {
                    if (arg instanceof com.tts.dto.ForgotPasswordRequest) {
                        String email = ((com.tts.dto.ForgotPasswordRequest) arg).getEmail();
                        if (email != null && !email.isEmpty()) {
                            String emailHash = hashString(email.toLowerCase().trim());
                            checkBucket("PASSWORD_RESET_EMAIL_" + emailHash, RateLimitAction.PASSWORD_RESET);
                        }
                    } else if (arg instanceof com.tts.dto.ResetPasswordRequest) {
                        String email = ((com.tts.dto.ResetPasswordRequest) arg).getEmail();
                        if (email != null && !email.isEmpty()) {
                            String emailHash = hashString(email.toLowerCase().trim());
                            checkBucket("PASSWORD_RESET_EMAIL_" + emailHash, RateLimitAction.PASSWORD_RESET);
                        }
                    }
                }
            }
            case TTS -> {
                Long userId = (Long) req.getAttribute("userId");
                if (userId != null) {
                    checkBucket("TTS_USER_" + userId, RateLimitAction.TTS);
                } else {
                    checkBucket("TTS_IP_" + clientIp, RateLimitAction.TTS);
                }
            }
            case STT -> {
                Long userId = (Long) req.getAttribute("userId");
                if (userId != null) {
                    checkBucket("STT_USER_" + userId, RateLimitAction.STT);
                } else {
                    checkBucket("STT_IP_" + clientIp, RateLimitAction.STT);
                }
            }
            case PING -> {
                checkBucket("PING_" + clientIp, RateLimitAction.PING);
            }
            case LIVE_PARAM -> {
                checkBucket("LIVE_PARAM_" + clientIp, RateLimitAction.LIVE_PARAM);
            }
        }

        return joinPoint.proceed();
    }

    private void checkBucket(String key, RateLimitAction action) {
        Bucket bucket = rateLimitBuckets.computeIfAbsent(key, k -> createBucketForAction(action));
        ConsumptionProbe probe = bucket.tryConsumeAndReturnRemaining(1);

        if (!probe.isConsumed()) {
            long wait = probe.getNanosToWaitForRefill() / 1_000_000_000;
            log.warn("Rate limit hit for key: {} (Action: {})", key, action);
            throw new RateLimitExceededException("Too many requests. Please try again later.", wait);
        }
    }

    private Bucket createBucketForAction(RateLimitAction action) {
        return switch (action) {
            case AUTH -> rateLimitConfig.createAuthBucket();
            case TTS -> rateLimitConfig.createTtsBucket();
            case PUBLIC -> rateLimitConfig.createPublicBucket();
            case LIVE_PARAM -> rateLimitConfig.createLiveParamBucket();
            case PING -> rateLimitConfig.createPingBucket();
            case STT -> rateLimitConfig.createSttBucket();
            case OTP_VERIFY -> rateLimitConfig.createOtpVerifyBucket();
            case OTP_RESEND -> rateLimitConfig.createOtpResendBucket();
            case PASSWORD_RESET -> rateLimitConfig.createPasswordResetBucket();
        };
    }

    private String extractRealIp(HttpServletRequest request) {
        String ip = request.getHeader("CF-Connecting-IP");
        if (ip != null && !ip.isEmpty()) return ip;
        
        ip = request.getHeader("X-Real-IP");
        if (ip != null && !ip.isEmpty()) return ip;
        
        ip = request.getHeader("X-Forwarded-For");
        if (ip != null && !ip.isEmpty()) return ip.split(",")[0].trim();
        
        return request.getRemoteAddr();
    }

    private String extractDeviceFingerprint(HttpServletRequest request) {
        StringBuilder fp = new StringBuilder();
        fp.append(request.getHeader("User-Agent")).append("|");
        fp.append(request.getHeader("Accept-Language")).append("|");
        fp.append(request.getHeader("Accept-Encoding")).append("|");
        fp.append(request.getHeader("Sec-CH-UA")).append("|");
        fp.append(request.getHeader("Sec-CH-UA-Platform"));
        return hashString(fp.toString());
    }

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
