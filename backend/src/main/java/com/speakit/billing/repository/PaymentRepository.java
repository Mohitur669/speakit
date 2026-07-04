package com.speakit.billing.repository;

import com.speakit.billing.entity.Payment;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    Optional<Payment> findByRazorpayOrderId(String razorpayOrderId);

    @Query(value = "SELECT p FROM Payment p LEFT JOIN FETCH p.subscription WHERE p.user.id = :userId ORDER BY p.createdAt DESC",
           countQuery = "SELECT COUNT(p) FROM Payment p WHERE p.user.id = :userId")
    Page<Payment> findByUserIdOrderByCreatedAtDesc(@Param("userId") Long userId, Pageable pageable);
}
