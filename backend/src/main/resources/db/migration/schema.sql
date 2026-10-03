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
    full_name VARCHAR(100),
    email VARCHAR(100) NOT NULL UNIQUE,
    phone_number VARCHAR(15) UNIQUE, -- Optional
    avatar_url VARCHAR(512),
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

    -- Tracking / Avatar Daily Limit Fields
    avatar_change_count INTEGER NOT NULL DEFAULT 0,
    last_avatar_change_date DATE,

    -- Usage Ledger (write-forward accumulators — NEVER decremented by history deletes)
    -- These are the source-of-truth for billing/quota; history rows are display-only.
    monthly_tts_chars_used BIGINT NOT NULL DEFAULT 0,
    monthly_stt_chars_used BIGINT NOT NULL DEFAULT 0,
    usage_month            DATE    NOT NULL DEFAULT DATE_TRUNC('month', CURRENT_DATE),

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
    full_text TEXT,

    -- Audio Storage (Cloudflare R2 / S3 or Local Fallback)
    audio_url VARCHAR(512),
    storage_key VARCHAR(255),

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
    plan_type VARCHAR(20),
    razorpay_order_id VARCHAR(100) UNIQUE NOT NULL,
    razorpay_payment_id VARCHAR(100),
    razorpay_signature VARCHAR(255),
    amount DECIMAL(19, 4) NOT NULL,
    currency VARCHAR(10) NOT NULL DEFAULT 'INR',
    tax_amount DECIMAL(19, 4) DEFAULT 0,
    invoice_number VARCHAR(50),
    payment_provider VARCHAR(30) DEFAULT 'RAZORPAY',
    payment_method VARCHAR(50),
    notes VARCHAR(500),
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
('IOS_FREE_PLAN_PRICE', '0', 'Dollar price for Free tier on iOS App Store'),
('IOS_PRO_PLAN_PRICE', '9.99', 'Dollar price for Pro monthly subscription on iOS App Store'),
('IOS_PRO_PLUS_PLAN_PRICE', '19.99', 'Dollar price for Pro Plus subscription on iOS App Store'),
('ENTERPRISE_PLAN_PRICE_INR', '0', 'Contact sales for Enterprise pricing'),
('PRO_PLAN_ID_RAZORPAY', '', 'Razorpay Plan ID for Pro monthly subscription'),
('PRO_PLUS_PLAN_ID_RAZORPAY', '', 'Razorpay Plan ID for Pro Plus monthly subscription'),
('RAZORPAY_SUBSCRIPTION_BILLING_CYCLES', '60', 'Default billing cycles count for monthly subscription'),
('MAX_FREE_CHARACTERS', '100', 'Character limit for free tier requests'),
('MAX_PRO_CHARACTERS', '200', 'Character limit for Pro tier requests'),
('MAX_PRO_PLUS_CHARACTERS', '500', 'Character limit for Pro Plus tier requests'),
('MAX_ENTERPRISE_CHARACTERS', '2000', 'Character limit for Enterprise tier requests'),
('MONTHLY_FREE_CHARACTERS', '3000', 'Total monthly character quota for Free tier'),
('MONTHLY_PRO_CHARACTERS', '5000', 'Total monthly character quota for Pro tier'),
('MONTHLY_PRO_PLUS_CHARACTERS', '10000', 'Total monthly character quota for Pro Plus tier'),
('MONTHLY_ENTERPRISE_CHARACTERS', '1000000', 'Total monthly character quota for Enterprise tier'),
('SHOW_BETA_FEATURES', 'false', 'Toggle for experimental UI components'),
('DYNAMIC_PLAN_FEATURES_LIVE', 'Y', 'When Y, plan limits and features bypass cache and fetch live parameters; otherwise use cached parameters'),
('SYSTEM_STATUS', 'Operational', 'Current live status of the AI voice engine'),
('FREE_PLAN_SYNTHESIZE_LIMIT', '5', 'Daily synthesis limit for free tier users'),
('FREE_PLAN_FEATURES', 'Standard Voices;100 chars / request;5 daily syntheses', 'Features list for free tier'),
('PRO_PLAN_FEATURES', '200 chars / request;Indian Voices;Indian Language; Everything From Free', 'Features list for pro tier'),
('PRO_PLUS_PLAN_FEATURES', '500 chars / request;ElevenLabs AI Voices; Priority Support; Everything From Pro', 'Features list for pro plus tier'),
('ENTERPRISE_PLAN_FEATURES', 'Custom Character Limits; API Access; Custom Feature Requests', 'Features list for enterprise tier'),
('MANAGE_PLAN_URL_WEB', 'https://speakit.mohitur.com', 'Web host URL for web app navigation and billing'),
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
('LIVE_RECORDING_ENABLED', 'true', 'Global toggle for Speech-to-Text Live Recording feature'),
('VOICE_BRIDGE_FLAG', 'N', 'Feature flag to enable or disable Voice Bridge feature (Y/N)')
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
    language VARCHAR(50),
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

-- 10. Pending Registrations Staging Table (For Pre-Verification Signup Quarantine)
CREATE SEQUENCE IF NOT EXISTS pending_registrations_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS pending_registrations (
    id BIGINT PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    full_name VARCHAR(100),
    phone_number VARCHAR(15),
    password_hash VARCHAR(255) NOT NULL,
    otp_hash VARCHAR(255) NOT NULL,
    attempts_remaining INTEGER NOT NULL DEFAULT 5,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING', -- PENDING, VERIFIED, EXPIRED
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version BIGINT NOT NULL DEFAULT 0
);

COMMENT ON TABLE pending_registrations IS 'Pre-verification signup staging table ensuring primary users table holds only verified users';

CREATE INDEX IF NOT EXISTS idx_pending_reg_email ON pending_registrations(email);
CREATE INDEX IF NOT EXISTS idx_pending_reg_username ON pending_registrations(username);
CREATE INDEX IF NOT EXISTS idx_pending_reg_status ON pending_registrations(status);
CREATE INDEX IF NOT EXISTS idx_pending_reg_expires_at ON pending_registrations(expires_at);

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
        ALTER TABLE users ADD CONSTRAINT users_phone_number_unique UNIQUE (phone_number);
    ELSE
        -- Ensure phone_number is optional (nullable)
        ALTER TABLE users ALTER COLUMN phone_number DROP NOT NULL;
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

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='auth_provider') THEN
        ALTER TABLE users DROP COLUMN auth_provider;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='display_name') THEN
        ALTER TABLE users DROP COLUMN display_name;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='last_login_at') THEN
        ALTER TABLE users DROP COLUMN last_login_at;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='supabase_user_id') THEN
        ALTER TABLE users DROP CONSTRAINT IF EXISTS uktamcja6eov3opw7ij5pm3o3v7;
        ALTER TABLE users DROP COLUMN supabase_user_id;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_email') THEN
        ALTER TABLE users DROP COLUMN pending_email;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_username') THEN
        ALTER TABLE users DROP COLUMN pending_username;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_phone_number') THEN
        ALTER TABLE users DROP COLUMN pending_phone_number;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_password') THEN
        ALTER TABLE users DROP COLUMN pending_password;
    END IF;

    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='pending_email_verified') THEN
        ALTER TABLE users DROP COLUMN pending_email_verified;
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

    -- Ensure full_name exists on users table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='full_name') THEN
        ALTER TABLE users ADD COLUMN full_name VARCHAR(100);
    END IF;

    -- Ensure avatar_url exists on users table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='avatar_url') THEN
        ALTER TABLE users ADD COLUMN avatar_url VARCHAR(512);
    END IF;

    -- Ensure avatar daily limit tracking columns exist on users table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='avatar_change_count') THEN
        ALTER TABLE users ADD COLUMN avatar_change_count INTEGER DEFAULT 0 NOT NULL;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='users' AND column_name='last_avatar_change_date') THEN
        ALTER TABLE users ADD COLUMN last_avatar_change_date DATE;
    END IF;

    -- Ensure full_text exists on tts_history table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='full_text') THEN
        ALTER TABLE tts_history ADD COLUMN full_text TEXT;
    END IF;

    -- Ensure audio_url and storage_key exist on tts_history table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='audio_url') THEN
        ALTER TABLE tts_history ADD COLUMN audio_url VARCHAR(512);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tts_history' AND column_name='storage_key') THEN
        ALTER TABLE tts_history ADD COLUMN storage_key VARCHAR(255);
    END IF;

    -- Ensure plan_type exists on payments table (Immutable Audit Ledger)
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='plan_type') THEN
        ALTER TABLE payments ADD COLUMN plan_type VARCHAR(20);
        UPDATE payments p SET plan_type = s.plan_type
        FROM subscriptions s
        WHERE p.subscription_id = s.id AND p.plan_type IS NULL;
    END IF;

    -- Ensure payment_provider and payment_method exist on payments table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='payment_provider') THEN
        ALTER TABLE payments ADD COLUMN payment_provider VARCHAR(30) DEFAULT 'RAZORPAY';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='payment_method') THEN
        ALTER TABLE payments ADD COLUMN payment_method VARCHAR(50);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payments' AND column_name='notes') THEN
        ALTER TABLE payments ADD COLUMN notes VARCHAR(500);
    END IF;

    -- Ensure STT transcript and metadata columns exist on speech_to_text_requests table
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='speech_to_text_requests' AND column_name='transcript') THEN
        ALTER TABLE speech_to_text_requests ADD COLUMN transcript TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='speech_to_text_requests' AND column_name='transliteration') THEN
        ALTER TABLE speech_to_text_requests ADD COLUMN transliteration TEXT;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='speech_to_text_requests' AND column_name='processing_mode') THEN
        ALTER TABLE speech_to_text_requests ADD COLUMN processing_mode VARCHAR(30);
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='speech_to_text_requests' AND column_name='original_filename') THEN
        ALTER TABLE speech_to_text_requests ADD COLUMN original_filename VARCHAR(255);
    END IF;

    -- Ensure iOS plan price parameters & feature flags exist
    INSERT INTO system_parameters (parameter_name, parameter_value, description)
    VALUES
        ('IOS_PRO_PLAN_PRICE', '9.99', 'Dollar price for Pro monthly subscription on iOS App Store'),
        ('IOS_PRO_PLUS_PLAN_PRICE', '19.99', 'Dollar price for Pro Plus subscription on iOS App Store'),
        ('VOICE_BRIDGE_FLAG', 'N', 'Feature flag to enable or disable Voice Bridge feature (Y/N)')
    ON CONFLICT (parameter_name) DO NOTHING;
END $$;

-- ============================================================================
-- USER AVATAR HISTORY TABLE & AUDIT (Industry Standard Media Lifecycle)
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS user_avatar_history_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS user_avatar_history (
    id BIGINT PRIMARY KEY,
    user_id BIGINT NOT NULL,
    avatar_url VARCHAR(512),
    storage_key VARCHAR(255),
    action VARCHAR(20) NOT NULL,          -- 'UPLOAD' or 'DELETE'
    file_size_bytes BIGINT,
    mime_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE,
    version BIGINT DEFAULT 0,
    CONSTRAINT fk_avatar_history_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_avatar_history_user_date ON user_avatar_history(user_id, action, created_at);

-- ─────────────────────────────────────────────────────────────────────────────
-- Usage Ledger Migration (idempotent — safe to re-run on existing databases)
-- Adds write-forward accumulators to users table. These columns are NEVER
-- decremented by history deletes; they are the billing source-of-truth.
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS monthly_tts_chars_used BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS monthly_stt_chars_used BIGINT NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS usage_month DATE NOT NULL DEFAULT DATE_TRUNC('month', CURRENT_DATE);

COMMENT ON COLUMN users.monthly_tts_chars_used IS 'Write-forward TTS character accumulator for current billing month. Never decremented on history deletes.';
COMMENT ON COLUMN users.monthly_stt_chars_used IS 'Write-forward STT character accumulator for current billing month. Never decremented on history deletes.';
COMMENT ON COLUMN users.usage_month            IS 'Billing month this accumulator covers. When month rolls over, both counters reset to 0.';

-- ─────────────────────────────────────────────────────────────────────────────
-- Multi-language Live Conversation support for speech_to_text_requests
-- Allows language column to store multiple codes (e.g. 'hi-IN, en-IN') up to 50 chars
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE speech_to_text_requests ALTER COLUMN language TYPE VARCHAR(50);

-- ─────────────────────────────────────────────────────────────────────────────
-- Client-Generated Unique Session UUID (Idempotency Key for Live Sessions)
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE speech_to_text_requests ADD COLUMN IF NOT EXISTS session_id VARCHAR(64);
CREATE UNIQUE INDEX IF NOT EXISTS idx_stt_user_session_id ON speech_to_text_requests(user_id, session_id) WHERE session_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────────────────────
-- Structured Live Session Dialogue Turns (Parent-Child Audit-Friendly Model)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SEQUENCE IF NOT EXISTS live_session_turn_seq START WITH 1 INCREMENT BY 50;

CREATE TABLE IF NOT EXISTS live_session_turns (
    id                  BIGINT PRIMARY KEY,
    request_id          BIGINT NOT NULL REFERENCES speech_to_text_requests(id) ON DELETE CASCADE,
    turn_index          INTEGER NOT NULL,
    speaker_role        VARCHAR(16) NOT NULL,
    speaker_name        VARCHAR(64) NOT NULL,
    source_language     VARCHAR(16) NOT NULL,
    original_text       TEXT NOT NULL,
    target_language     VARCHAR(16),
    translated_text     TEXT,
    character_count     INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version             BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_live_turn_request_id ON live_session_turns(request_id, turn_index);
