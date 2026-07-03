package com.speakit.tts.repository;

import com.speakit.tts.entity.Subscription;
import com.speakit.tts.entity.User;
import com.speakit.tts.entity.SubscriptionStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;
import java.util.Optional;

@Repository
public interface SubscriptionRepository extends JpaRepository<Subscription, Long> {
    Optional<Subscription> findByRazorpaySubscriptionId(String razorpaySubscriptionId);
    Optional<Subscription> findByUserAndStatus(User user, SubscriptionStatus status);
}
