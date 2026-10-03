package com.speakit.user.repository;

/**
 * JPA repository for User entity providing data access
 * methods for authentication and user lookup operations.
 */
import com.speakit.user.entity.User;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import org.springframework.transaction.annotation.Transactional;

import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByUsername(String username);
    Optional<User> findByEmail(String email);
    Optional<User> findByPhoneNumber(String phoneNumber);
    
    @Query("SELECT u FROM User u WHERE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(u.phoneNumber, '+', ''), ' ', ''), '-', ''), '(', ''), ')', '') LIKE %:suffix")
    Optional<User> findByPhoneNumberSuffix(@Param("suffix") String suffix);
    
    Optional<User> findByUsernameOrEmail(String username, String email);

    @Query("SELECT u.id AS id, u.sessionVersion AS sessionVersion, u.planType AS planType, u.subscriptionStatus AS subscriptionStatus, u.planExpiry AS planExpiry FROM User u WHERE u.username = :username")
    Optional<UserSessionProjection> findSessionAndPlanByUsername(@Param("username") String username);

    @Modifying
    @Transactional
    @Query("UPDATE User u SET u.sessionVersion = u.sessionVersion + 1 WHERE u.username = :username")
    int incrementSessionVersion(@Param("username") String username);

    @Modifying
    @Transactional
    @Query("DELETE FROM User u WHERE u.emailVerified = false AND u.createdAt < :cutoff")
    int deleteUnverifiedUsersOlderThan(@Param("cutoff") java.time.LocalDateTime cutoff);

    // ── Usage Ledger Atomic Increments ────────────────────────────────────────
    // Always increment, never decrement. If the stored usageMonth is behind the
    // current calendar month, reset both counters and update usageMonth first.

    /**
     * Atomically increments the TTS character accumulator for the current billing
     * month. Resets both counters to 0 and advances usageMonth when a new
     * calendar month has started since the last write.
     */
    @Modifying
    @Transactional
    @Query("""
        UPDATE User u SET
            u.monthlyTtsCharsUsed = CASE
                WHEN u.usageMonth < :currentMonth THEN :chars
                ELSE u.monthlyTtsCharsUsed + :chars
            END,
            u.monthlySttCharsUsed = CASE
                WHEN u.usageMonth < :currentMonth THEN 0
                ELSE u.monthlySttCharsUsed
            END,
            u.usageMonth = :currentMonth
        WHERE u.id = :userId
        """)
    int incrementTtsCharsUsed(@Param("userId") Long userId,
                              @Param("chars") long chars,
                              @Param("currentMonth") java.time.LocalDate currentMonth);

    /**
     * Atomically increments the STT character accumulator for the current billing
     * month. Resets both counters to 0 and advances usageMonth when a new
     * calendar month has started since the last write.
     */
    @Modifying
    @Transactional
    @Query("""
        UPDATE User u SET
            u.monthlySttCharsUsed = CASE
                WHEN u.usageMonth < :currentMonth THEN :chars
                ELSE u.monthlySttCharsUsed + :chars
            END,
            u.monthlyTtsCharsUsed = CASE
                WHEN u.usageMonth < :currentMonth THEN 0
                ELSE u.monthlyTtsCharsUsed
            END,
            u.usageMonth = :currentMonth
        WHERE u.id = :userId
        """)
    int incrementSttCharsUsed(@Param("userId") Long userId,
                              @Param("chars") long chars,
                              @Param("currentMonth") java.time.LocalDate currentMonth);

    /**
     * Reads the current ledger values as a lightweight projection — avoids
     * loading the full User entity for usage checks.
     */
    @Query("SELECT u.monthlyTtsCharsUsed AS ttsChars, u.monthlySttCharsUsed AS sttChars, u.usageMonth AS usageMonth FROM User u WHERE u.id = :userId")
    java.util.Optional<UsageLedgerProjection> findUsageLedgerById(@Param("userId") Long userId);
}
