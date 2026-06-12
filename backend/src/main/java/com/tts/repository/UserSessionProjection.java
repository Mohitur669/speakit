package com.tts.repository;

import com.tts.entity.PlanType;

public interface UserSessionProjection {
    Long getId();
    Long getSessionVersion();
    PlanType getPlanType();
}
