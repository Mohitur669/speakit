-- Migration V2: Add audio_url and storage_key to speech_to_text_requests for STT audio persistence & CDN streaming
ALTER TABLE speech_to_text_requests ADD COLUMN IF NOT EXISTS audio_url VARCHAR(512);
ALTER TABLE speech_to_text_requests ADD COLUMN IF NOT EXISTS storage_key VARCHAR(255);
