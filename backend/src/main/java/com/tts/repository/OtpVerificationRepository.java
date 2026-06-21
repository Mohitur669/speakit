package com.tts.repository;

import com.tts.entity.OtpVerification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

public interface OtpVerificationRepository extends JpaRepository<OtpVerification, Long> {

    Optional<OtpVerification> findFirstByEmailAndPurposeAndConsumedFalseOrderByCreatedAtDesc(String email, String purpose);

    List<OtpVerification> findAllByEmailAndPurposeAndConsumedFalse(String email, String purpose);

    @Modifying
    @Query("UPDATE OtpVerification o SET o.consumed = true WHERE o.email = :email AND o.purpose = :purpose AND o.consumed = false")
    int invalidateExistingOtps(@Param("email") String email, @Param("purpose") String purpose);

    @Modifying
    @Query("DELETE FROM OtpVerification o WHERE o.expiresAt < :now")
    int pruneExpiredOtps(@Param("now") LocalDateTime now);
}
