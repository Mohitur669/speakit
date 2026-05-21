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
    password VARCHAR(255) NOT NULL,
    
    -- Status/Flags
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    has_natural_voice_access BOOLEAN NOT NULL DEFAULT FALSE,
    
    -- Audit Fields
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
    output_format VARCHAR(10) NOT NULL,
    character_count INTEGER NOT NULL,
    is_neural BOOLEAN NOT NULL DEFAULT FALSE,
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
    plan_type VARCHAR(20) NOT NULL, -- BASIC, PRO, ENTERPRISE
    status VARCHAR(20) NOT NULL, -- CREATED, ACTIVE, CANCELLED, EXPIRED, PENDING
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
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
    status VARCHAR(20) NOT NULL, -- INITIATED, SUCCESS, FAILED, REFUNDED
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
('PRO_PLAN_PRICE_INR', '499', 'Current price for Pro monthly subscription'),
('ENTERPRISE_PLAN_PRICE_INR', '1999', 'Current price for Enterprise subscription'),
('MAX_FREE_CHARACTERS', '3000', 'Character limit for free tier requests'),
('MAX_PRO_CHARACTERS', '10000', 'Character limit for Pro tier requests'),
('SHOW_BETA_FEATURES', 'false', 'Toggle for experimental UI components')
ON CONFLICT (parameter_name) DO NOTHING;
