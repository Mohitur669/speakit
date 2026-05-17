-- SpeakIT Database Schema
-- Database: PostgreSQL

-- 1. Create Users Table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    has_natural_voice_access BOOLEAN NOT NULL DEFAULT FALSE,
    session_version BIGINT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- 2. Create TTS History Table
CREATE TABLE IF NOT EXISTS tts_history (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id),
    voice_id VARCHAR(50) NOT NULL,
    output_format VARCHAR(10) NOT NULL,
    character_count INTEGER NOT NULL,
    is_neural BOOLEAN NOT NULL DEFAULT FALSE,
    text_snippet VARCHAR(100),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP
);

-- 3. Create Indexes for Performance
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_tts_history_user_id ON tts_history(user_id);
CREATE INDEX IF NOT EXISTS idx_tts_history_created_at ON tts_history(created_at);

-- 4. Comments for documentation
COMMENT ON TABLE users IS 'Stores user account information and feature access flags';
COMMENT ON COLUMN users.has_natural_voice_access IS 'Flag to determine if user can access AWS Polly Neural (Natural) voices';
COMMENT ON TABLE tts_history IS 'Stores analytics and logs for every text-to-speech conversion request';
