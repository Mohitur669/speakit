package com.speakit.user.service;

import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;
import com.speakit.user.repository.UserRepository;
import com.speakit.user.repository.UserSessionProjection;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.concurrent.TimeUnit;

/**
 * Service providing high-performance in-memory cached access to UserSessionProjection.
 * Shields PostgreSQL from repetitive per-request lookups in JwtAuthenticationFilter
 * while providing immediate cache eviction on session invalidation (logout/password reset).
 */
@Service
@Slf4j
public class UserSessionCacheService {

    private final UserRepository userRepository;

    public UserSessionCacheService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    // Cache user session projections for 60 seconds (maximum 10,000 entries)
    private final Cache<String, Optional<UserSessionProjection>> sessionCache = Caffeine.newBuilder()
            .maximumSize(10_000)
            .expireAfterWrite(60, TimeUnit.SECONDS)
            .build();

    /**
     * Retrieves the UserSessionProjection for the given username, utilizing
     * the in-memory Caffeine cache to avoid redundant database round-trips.
     */
    public Optional<UserSessionProjection> getUserSession(String username) {
        if (username == null) {
            return Optional.empty();
        }
        return sessionCache.get(username.toLowerCase(), key -> userRepository.findSessionAndPlanByUsername(key));
    }

    /**
     * Evicts the cached session projection for the given username immediately.
     * Must be called whenever session_version is incremented (logout, password reset, multi-login eviction).
     */
    public void evictSession(String username) {
        if (username != null) {
            sessionCache.invalidate(username.toLowerCase());
            log.debug("Evicted cached session projection for user: {}", username);
        }
    }
}
