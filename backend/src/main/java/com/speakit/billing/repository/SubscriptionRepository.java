package com.speakit.billing.repository;

import com.speakit.billing.entity.Subscription;
import com.speakit.user.entity.User;
import com.speakit.billing.entity.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.transaction.annotation.Transactional;
import java.util.Optional;

public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {
    Optional<Subscription> findByRazorpaySubscriptionId(String razorpaySubscriptionId);
    Optional<Subscription> findFirstByUserAndStatusOrderByIdDesc(User user, SubscriptionStatus status);

    @Modifying
    @Transactional
    @Query("UPDATE Subscription s SET s.user = null, s.status = com.speakit.billing.entity.SubscriptionStatus.CANCELLED WHERE s.user.id = :userId")
    int anonymizeSubscriptionsByUserId(@Param("userId") Long userId);
}
