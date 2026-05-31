package com.tts.repository;

public interface UserSessionProjection {
    Long getId();
    Long getSessionVersion();
    boolean getHasNaturalVoiceAccess();
    String getPlanType();
}
