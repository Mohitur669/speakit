package com.tts.aspect;

public enum RateLimitAction {
    AUTH,       // Strict protection for login/register (Brute-force)
    TTS,        // High-cost AWS Polly operations (Cost explosion)
    PUBLIC,     // General public API (Scraping/Spam)
    LIVE_PARAM, // System parameters (Probing protection)
    PING,       // Keep-alive health check (Render sleep prevention)
    STT,        // Speech-to-Text operations (Cost/Abuse protection)
    OTP_VERIFY, // Rate limit for OTP code checks (protects against guessing)
    OTP_RESEND, // Cooldown rate limit for resending OTPs
    PASSWORD_RESET // Rate limit for forgot password and reset requests
}
