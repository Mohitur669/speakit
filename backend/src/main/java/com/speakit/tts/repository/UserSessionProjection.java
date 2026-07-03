package com.speakit.tts.repository;

import com.speakit.tts.entity.PlanType;
import com.speakit.tts.entity.SubscriptionStatus;
import org.springframework.lang.Nullable;
import java.time.LocalDateTime;

public interface UserSessionProjection {
    Long getId();
    Long getSessionVersion();
    PlanType getPlanType();
    SubscriptionStatus getSubscriptionStatus();
    @Nullable
    LocalDateTime getPlanExpiry();
}
