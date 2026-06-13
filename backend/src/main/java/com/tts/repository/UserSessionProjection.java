package com.tts.repository;

import com.tts.entity.PlanType;
import com.tts.entity.SubscriptionStatus;
import java.time.LocalDateTime;

public interface UserSessionProjection {
    Long getId();
    Long getSessionVersion();
    PlanType getPlanType();
    SubscriptionStatus getSubscriptionStatus();
    LocalDateTime getPlanExpiry();
}
