-- SpeakIT Database Schema
-- Database: PostgreSQL

-- 1. Create Users Table
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    username VARCHAR(255) NOT NULL UNIQUE,
    email VARCHAR(255) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    has_natural_voice_access BOOLEAN NOT NULL DEFAULT FALSE
);

-- 2. Create Indexes
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- 3. Sample Data (Optional)
-- Note: Password is 'password' hashed with BCrypt
-- INSERT INTO users (username, password, has_natural_voice_access) 
-- VALUES ('admin', '$2a$10$8.UnVuG9HHgffUDAlk8qfOuVGkqRzgVymGe07xd00W1z56.f1MeO.', true);

-- 4. Comments for documentation
COMMENT ON TABLE users IS 'Stores user account information and feature access flags';
COMMENT ON COLUMN users.has_natural_voice_access IS 'Flag to determine if user can access AWS Polly Neural (Natural) voices';
