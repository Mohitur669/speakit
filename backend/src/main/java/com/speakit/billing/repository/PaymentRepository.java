package com.speakit.billing.repository;

import com.speakit.billing.entity.Payment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.Optional;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByRazorpayOrderId(String razorpayOrderId);

    @Query(value = "SELECT p FROM Payment p LEFT JOIN FETCH p.subscription WHERE p.user.id = :userId ORDER BY p.createdAt DESC",
           countQuery = "SELECT COUNT(p) FROM Payment p WHERE p.user.id = :userId")
    Page<Payment> findByUserIdOrderByCreatedAtDesc(@Param("userId") Long userId, Pageable pageable);

    @org.springframework.data.jpa.repository.Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query("UPDATE Payment p SET p.status = com.speakit.billing.entity.PaymentStatus.FAILED WHERE p.status = com.speakit.billing.entity.PaymentStatus.PENDING AND p.createdAt < :cutoff")
    int markStalePendingPaymentsAsFailed(@Param("cutoff") java.time.LocalDateTime cutoff);
}
