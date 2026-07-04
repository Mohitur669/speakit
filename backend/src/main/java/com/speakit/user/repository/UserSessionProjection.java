package com.speakit.user.repository;

import com.speakit.billing.entity.PlanType;
import com.speakit.billing.entity.SubscriptionStatus;
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
