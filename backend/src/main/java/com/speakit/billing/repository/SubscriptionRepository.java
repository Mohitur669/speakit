package com.speakit.billing.repository;

import com.speakit.billing.entity.Subscription;
import com.speakit.user.entity.User;
import com.speakit.billing.entity.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {
    Optional<Subscription> findByRazorpaySubscriptionId(String razorpaySubscriptionId);
    Optional<Subscription> findFirstByUserAndStatusOrderByIdDesc(User user, SubscriptionStatus status);
}
