package com.speakit.auth.repository;

import com.speakit.auth.entity.OtpVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface OtpVerificationRepository extends JpaRepository<OtpVerification, Long> {

    Optional<OtpVerification> findFirstByEmailIgnoreCaseAndPurposeAndConsumedFalseOrderByCreatedAtDesc(String email, String purpose);

    Optional<OtpVerification> findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(String email, String purpose);

    List<OtpVerification> findAllByEmailIgnoreCaseAndPurposeAndConsumedFalse(String email, String purpose);

    List<OtpVerification> findAllByEmailAndPurposeAndConsumedFalse(String email, String purpose);

    @Modifying
    @Query("UPDATE OtpVerification o SET o.consumed = true WHERE LOWER(TRIM(o.email)) = LOWER(TRIM(:email)) AND o.purpose = :purpose AND o.consumed = false")
    int invalidateExistingOtps(@Param("email") String email, @Param("purpose") String purpose);

    @Modifying
    @Query("DELETE FROM OtpVerification o WHERE o.expiresAt < :now")
    int pruneExpiredOtps(@Param("now") LocalDateTime now);

    @Modifying
    @Query("DELETE FROM OtpVerification o WHERE o.user.id IN (SELECT u.id FROM User u WHERE u.emailVerified = false AND u.createdAt < :cutoff)")
    int deleteOtpsForUnverifiedUsersOlderThan(@Param("cutoff") LocalDateTime cutoff);

    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("DELETE FROM OtpVerification o WHERE o.user.id = :userId OR LOWER(TRIM(o.email)) = LOWER(TRIM(:email))")
    int deleteAllByUserIdOrEmail(@Param("userId") Long userId, @Param("email") String email);
}
