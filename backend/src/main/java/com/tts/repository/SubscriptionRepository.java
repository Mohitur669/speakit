package com.tts.repository;

import com.tts.entity.Subscription;
import com.tts.entity.User;
import com.tts.entity.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {
    Optional<Subscription> findByRazorpaySubscriptionId(String razorpaySubscriptionId);
    Optional<Subscription> findByUserAndStatus(User user, SubscriptionStatus status);
}
