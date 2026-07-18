-- SpeakIT Database Schema (Enterprise Standard)
-- Database: PostgreSQL

-- 0. Create Sequences for Production-Grade ID Generation
CREATE SEQUENCE IF NOT EXISTS users_seq START WITH 1 INCREMENT BY 50;
CREATE SEQUENCE IF NOT EXISTS tts_history_seq START WITH 1 INCREMENT BY 50;

-- 1. Create Users Table
CREATE TABLE IF NOT EXISTS users (
    -- Primary Key (Internal sequential for performance)
    id BIGINT PRIMARY KEY,

    -- Core Business Data
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(15) NOT NULL UNIQUE, -- NOT NULL enforced
    password VARCHAR(255) NOT NULL,

    -- Status/Flags
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    plan_type VARCHAR(20) NOT NULL DEFAULT 'FREE',
    subscription_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    plan_expiry TIMESTAMP WITH TIME ZONE,
    role VARCHAR(20) NOT NULL DEFAULT 'USER',

    -- Verification & Update Fields
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    account_status VARCHAR(30) NOT NULL DEFAULT 'PENDING_VERIFICATION',
    pending_email VARCHAR(100),
    pending_username VARCHAR(50),
    pending_phone_number VARCHAR(15),
    pending_password VARCHAR(255),

    -- Audit Fields
    consent_accepted BOOLEAN NOT NULL DEFAULT FALSE,
    consent_timestamp TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Versioning/Optimistic Locking
    session_version BIGINT NOT NULL DEFAULT 1,
    version BIGINT NOT NULL DEFAULT 0
);

-- 2. Create TTS History Table
CREATE TABLE IF NOT EXISTS tts_history (
    -- Primary Key
    id BIGINT PRIMARY KEY,

    -- Foreign Keys
    user_id BIGINT NOT NULL REFERENCES users(id),

    -- Core Business Data
    voice_id VARCHAR(50) NOT NULL,
    voice_name VARCHAR(100),
    voice_type VARCHAR(20) NOT NULL DEFAULT 'STANDARD', -- STANDARD, NEURAL, NATURAL
    output_format VARCHAR(10) NOT NULL,
    character_count INTEGER NOT NULL,
    text_snippet VARCHAR(100),

    -- Audit Fields
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,

    -- Versioning
    version BIGINT NOT NULL DEFAULT 0
);

-- 3. Performance & Lookup Indexes
-- User Lookups
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- History Analytics & Filtering
CREATE INDEX IF NOT EXISTS idx_tts_history_user_id ON tts_history(user_id);
CREATE INDEX IF NOT EXISTS idx_tts_history_created_at ON tts_history(created_at);

-- 4. Documentation Comments
COMMENT ON TABLE users IS 'Master user registry with authentication, status, and feature flags';
COMMENT ON TABLE tts_history IS 'Comprehensive analytics log for all voice generation requests';
COMMENT ON COLUMN users.session_version IS 'Internal counter for JWT invalidation and logout-from-all-devices';
COMMENT ON COLUMN users.version IS 'Standard JPA optimistic locking version';

-- 5. Payment & Subscription System (Razorpay Integration)
CREATE SEQUENCE IF NOT EXISTS subscriptions_seq START WITH 1 INCREMENT BY 50;
CREATE SEQUENCE IF NOT EXISTS payments_seq START WITH 1 INCREMENT BY 50;
CREATE SEQUENCE IF NOT EXISTS webhook_events_seq START WITH 1 INCREMENT BY 50;

-- Subscriptions Table
CREATE TABLE IF NOT EXISTS subscriptions (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    razorpay_subscription_id VARCHAR(100) UNIQUE,
    plan_type VARCHAR(20) NOT NULL, -- FREE, PRO, PRO_PLUS, ENTERPRISE
    status VARCHAR(20) NOT NULL, -- ACTIVE, TRIAL, PAST_DUE, CANCELLED, EXPIRED, etc.
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    next_billing_date TIMESTAMP WITH TIME ZONE,
    cancel_at_period_end BOOLEAN DEFAULT FALSE,
    cancelled_at TIMESTAMP WITH TIME ZONE,
    trial_start TIMESTAMP WITH TIME ZONE,
    trial_end TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

-- Payments Table
CREATE TABLE IF NOT EXISTS payments (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    subscription_id BIGINT REFERENCES subscriptions(id),
    razorpay_order_id VARCHAR(100) UNIQUE NOT NULL,
    razorpay_payment_id VARCHAR(100),
    razorpay_signature VARCHAR(255),
    amount DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    tax_amount DECIMAL(19, 4) DEFAULT 0,
    invoice_number VARCHAR(50),
    status VARCHAR(20) NOT NULL, -- SUCCESS, FAILED, PENDING, REFUNDED, etc.
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

-- Webhook Events Table (For Idempotency & Audit)
CREATE TABLE IF NOT EXISTS webhook_events (
    id BIGINT PRIMARY KEY,
    event_id VARCHAR(100) UNIQUE NOT NULL,
    payload TEXT NOT NULL,
    status VARCHAR(20) NOT NULL, -- RECEIVED, PROCESSED, FAILED
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Payment System Indexes
CREATE INDEX IF NOT EXISTS idx_subscriptions_user_id ON subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON subscriptions(status);
CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments(razorpay_order_id);
CREATE INDEX IF NOT EXISTS idx_webhook_events_event_id ON webhook_events(event_id);

-- 6. System Parameters & Feature Flags
CREATE TABLE IF NOT EXISTS system_parameters (
    parameter_name VARCHAR(100) PRIMARY KEY,
    parameter_value TEXT,
    description VARCHAR(255),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by VARCHAR(50) NOT NULL DEFAULT 'SYSTEM',
    version BIGINT NOT NULL DEFAULT 0
);

-- Seed Initial Parameters
INSERT INTO system_parameters (parameter_name, parameter_value, description) VALUES
('ENABLE_RAZORPAY', 'true', 'Global toggle for payment gateway'),
('PRO_PLAN_PRICE_INR', '1', 'Current price for Pro monthly subscription'),
('PRO_PLUS_PLAN_PRICE_INR', '2', 'Current price for Pro Plus subscription'),
('ENTERPRISE_PLAN_PRICE_INR', '0', 'Contact sales for Enterprise pricing'),
('PRO_PLAN_ID_RAZORPAY', '', 'Razorpay Plan ID for Pro monthly subscription'),
('PRO_PLUS_PLAN_ID_RAZORPAY', '', 'Razorpay Plan ID for Pro Plus monthly subscription'),
('RAZORPAY_SUBSCRIPTION_BILLING_CYCLES', '60', 'Default billing cycles count for monthly subscription'),
('MAX_FREE_CHARACTERS', '100', 'Character limit for free tier requests'),
('MAX_PRO_CHARACTERS', '200', 'Character limit for Pro tier requests'),
('MAX_PRO_PLUS_CHARACTERS', '500', 'Character limit for Pro Plus tier requests'),
('MAX_ENTERPRISE_CHARACTERS', '2000', 'Character limit for Enterprise tier requests'),
('SHOW_BETA_FEATURES', 'false', 'Toggle for experimental UI components'),
('SYSTEM_STATUS', 'Operational', 'Current live status of the AI voice engine'),
('FREE_PLAN_SYNTHESIZE_LIMIT', '5', 'Daily synthesis limit for free tier users'),
('FREE_PLAN_FEATURES', 'Standard Voices;100 chars / request;5 daily syntheses', 'Features list for free tier'),
('PRO_PLAN_FEATURES', '200 chars / request;Indian Voices;Indian Language; Everything From Free', 'Features list for pro tier'),
('PRO_PLUS_PLAN_FEATURES', '500 chars / request;ElevenLabs AI Voices; Priority Support; Everything From Pro', 'Features list for pro plus tier'),
('ENTERPRISE_PLAN_FEATURES', 'Custom Character Limits; API Access; Custom Feature Requests', 'Features list for enterprise tier'),
('STT_ENABLED', 'true', 'Global toggle for Speech-to-Text feature'),
('ELEVENLABS_ENABLED', 'true', 'Global toggle for ElevenLabs Natural AI voices'),
('SARVAM_ENABLED', 'true', 'Global toggle for Sarvam AI Indian regional voices'),
('AUTH_SESSION_DURATION_MS', '7200000', 'Maximum duration of a user session (2 hours)'),
('AUTH_IDLE_TIMEOUT_MS', '60000', 'Maximum idle time before session invalidation (1 minute)'),
('STT_MAX_FILE_SIZE_MB_PRO', '25', 'Max audio file size (MB) for Pro tier'),
('STT_MAX_FILE_SIZE_MB_PRO_PLUS', '50', 'Max audio file size (MB) for Pro Plus tier'),
('STT_MAX_FILE_SIZE_MB_ENTERPRISE', '500', 'Max audio file size (MB) for Enterprise tier'),
('STT_MAX_DURATION_MIN_PRO', '15', 'Max audio duration (minutes) for Pro tier'),
('STT_MAX_DURATION_MIN_PRO_PLUS', '30', 'Max audio duration (minutes) for Pro Plus tier'),
('STT_MAX_DURATION_MIN_ENTERPRISE', '120', 'Max audio duration (minutes) for Enterprise tier'),
('STT_DAILY_QUOTA_PRO', '100', 'Daily STT transcription limit for Pro tier'),
('STT_DAILY_QUOTA_PRO_PLUS', '500', 'Daily STT transcription limit for Pro Plus tier'),
('STT_DAILY_QUOTA_ENTERPRISE', '5000', 'Daily STT transcription limit for Enterprise tier'),
('STT_DEDUPE_WINDOW_MS', '60000', 'Time window to block duplicate STT requests'),
('SELF_PING_URL', '', 'Dynamic external URL for system self-ping to prevent spin-down'),
('KEEP_ALIVE_ENABLED', 'true', 'Toggle to enable or disable the system self-ping dynamically'),
('LIVE_RECORDING_ENABLED', 'true', 'Global toggle for Speech-to-Text Live Recording feature')
ON CONFLICT (parameter_name) DO NOTHING;

-- Accepted values for SYSTEM_STATUS
-- Emerald: "Operational"
-- Amber: "Maintenance"
-- Red: "Outage"

-- 7. Contact Us Submissions
CREATE SEQUENCE IF NOT EXISTS contact_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS contact_submissions (
    id BIGINT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    topic VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    ip_address VARCHAR(45),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE contact_submissions IS 'Secure registry for public contact form inquiries and support requests';

CREATE INDEX IF NOT EXISTS idx_contact_email ON contact_submissions(email);
CREATE INDEX IF NOT EXISTS idx_contact_created_at ON contact_submissions(created_at);

-- 8. Speech to Text Requests
CREATE SEQUENCE IF NOT EXISTS stt_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS speech_to_text_requests (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    provider VARCHAR(20) NOT NULL,
    audio_duration_seconds INTEGER,
    audio_size_bytes BIGINT,
    language VARCHAR(10),
    transcript_length INTEGER,
    status VARCHAR(20) NOT NULL,
    failure_reason VARCHAR(255),
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_stt_user_id ON speech_to_text_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_stt_created_at ON speech_to_text_requests(created_at);

-- 9. OTP Verifications Table (Email Verification, Password Reset, Email Change)
CREATE SEQUENCE IF NOT EXISTS otp_verifications_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS otp_verifications (
    id BIGINT PRIMARY KEY,
    user_id BIGINT REFERENCES users(id),
    email VARCHAR(100) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    purpose VARCHAR(30) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    attempts_remaining INTEGER NOT NULL DEFAULT 5,
    consumed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_otp_email ON otp_verifications(email);
CREATE INDEX IF NOT EXISTS idx_otp_expires_at ON otp_verifications(expires_at);

-- Migration Helper for existing databases
DO $$
BEGIN
    -- Remove legacy column if it exists
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='has_natural_voice_access') THEN
        ALTER TABLE users DROP COLUMN has_natural_voice_access;
    END IF;

    -- Normalize Subscription Status (Migration from PENDING to PAYMENT_PENDING)
    UPDATE subscriptions SET status = 'PAYMENT_PENDING' WHERE status = 'PENDING';

    -- Ensure new subscription columns exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscriptions' AND column_name='cancel_at_period_end') THEN
        ALTER TABLE subscriptions ADD COLUMN cancel_at_period_end BOOLEAN DEFAULT FALSE;
        UPDATE subscriptions SET cancel_at_period_end = FALSE WHERE cancel_at_period_end IS NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscriptions' AND column_name='next_billing_date') THEN
        ALTER TABLE subscriptions ADD COLUMN next_billing_date TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscriptions' AND column_name='cancelled_at') THEN
        ALTER TABLE subscriptions ADD COLUMN cancelled_at TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscriptions' AND column_name='trial_start') THEN
        ALTER TABLE subscriptions ADD COLUMN trial_start TIMESTAMP WITH TIME ZONE;
        ALTER TABLE subscriptions ADD COLUMN trial_end TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='phone_number') THEN
        ALTER TABLE users ADD COLUMN phone_number VARCHAR(15);
        -- Populate with username as temporary unique placeholder to avoid nulls
        UPDATE users SET phone_number = username WHERE phone_number IS NULL;
        ALTER TABLE users ALTER COLUMN phone_number SET NOT NULL;
        ALTER TABLE users ADD CONSTRAINT users_phone_number_unique UNIQUE (phone_number);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='role') THEN
        ALTER TABLE users ADD COLUMN role VARCHAR(20) DEFAULT 'USER' NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='subscription_status') THEN
        ALTER TABLE users ADD COLUMN subscription_status VARCHAR(20) DEFAULT 'ACTIVE' NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='plan_expiry') THEN
        ALTER TABLE users ADD COLUMN plan_expiry TIMESTAMP WITH TIME ZONE;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='plan_type') THEN
        ALTER TABLE users ADD COLUMN plan_type VARCHAR(20) DEFAULT 'FREE' NOT NULL;
    END IF;

    -- Ensure OTP-gating columns exist on users
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='email_verified') THEN
        ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
        ALTER TABLE users ALTER COLUMN email_verified SET NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='account_status') THEN
        ALTER TABLE users ADD COLUMN account_status VARCHAR(30) DEFAULT 'PENDING_VERIFICATION';
        ALTER TABLE users ALTER COLUMN account_status SET NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_email') THEN
        ALTER TABLE users ADD COLUMN pending_email VARCHAR(100);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_username') THEN
        ALTER TABLE users ADD COLUMN pending_username VARCHAR(50);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_phone_number') THEN
        ALTER TABLE users ADD COLUMN pending_phone_number VARCHAR(15);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_password') THEN
        ALTER TABLE users ADD COLUMN pending_password VARCHAR(255);
    END IF;

    -- One-time backfill of existing users to verified and ACTIVE status
    -- (Triggers only if the migration completion flag is not set in system_parameters)
    IF NOT EXISTS (SELECT 1 FROM system_parameters WHERE parameter_name = 'migration_email_verification_backfill') THEN
        INSERT INTO system_parameters (parameter_name, parameter_value, description, updated_at, updated_by, version)
        VALUES ('migration_email_verification_backfill', 'COMPLETED', 'One-time backfill of existing users to verified and ACTIVE', CURRENT_TIMESTAMP, 'SYSTEM', 0)
        ON CONFLICT (parameter_name) DO NOTHING;

        UPDATE users SET email_verified = TRUE, account_status = 'ACTIVE';
    END IF;

    -- History Table Migration
    -- 1. Ensure voice_name exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='voice_name') THEN
        ALTER TABLE tts_history ADD COLUMN voice_name VARCHAR(100);
    END IF;

    -- 2. Ensure voice_type exists
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='voice_type') THEN
        ALTER TABLE tts_history ADD COLUMN voice_type VARCHAR(20) DEFAULT 'STANDARD' NOT NULL;
    END IF;

    -- 3. Migrate data if old boolean columns still exist
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='is_eleven_labs') THEN
        -- Standardize data first (Handle case where voice_type might already have been added by Hibernate)
        UPDATE tts_history SET voice_type = 'NATURAL' WHERE is_eleven_labs = TRUE;
        
        IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='is_neural') THEN
            UPDATE tts_history SET voice_type = 'NEURAL' WHERE is_neural = TRUE AND is_eleven_labs = FALSE;
            ALTER TABLE tts_history DROP COLUMN is_neural;
        END IF;

        ALTER TABLE tts_history DROP COLUMN is_eleven_labs;
    END IF;
END $$;
