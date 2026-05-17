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
