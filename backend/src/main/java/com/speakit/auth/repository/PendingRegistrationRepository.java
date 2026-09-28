package com.speakit.auth.repository;

import com.speakit.auth.entity.PendingRegistration;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.Optional;

public interface PendingRegistrationRepository extends JpaRepository<PendingRegistration, Long> {

    Optional<PendingRegistration> findFirstByEmailIgnoreCaseAndStatusOrderByCreatedAtDesc(String email, String status);

    Optional<PendingRegistration> findFirstByUsernameIgnoreCaseAndStatusOrderByCreatedAtDesc(String username, String status);

    @Modifying
    @Query("UPDATE PendingRegistration p SET p.status = 'EXPIRED' WHERE LOWER(TRIM(p.email)) = LOWER(TRIM(:email)) AND p.status = 'PENDING'")
    int expireActiveRegistrationsForEmail(@Param("email") String email);

    @Modifying
    @Query("UPDATE PendingRegistration p SET p.status = 'EXPIRED' WHERE p.expiresAt < :cutoff AND p.status = 'PENDING'")
    int expireStaleRegistrations(@Param("cutoff") LocalDateTime cutoff);

    @Modifying
    @Query("DELETE FROM PendingRegistration p WHERE p.status = 'EXPIRED' AND p.updatedAt < :purgeCutoff")
    int deleteExpiredRegistrationsOlderThan(@Param("purgeCutoff") LocalDateTime purgeCutoff);
}
