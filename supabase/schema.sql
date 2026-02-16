-- TravianTimer: Datenbank-Schema
-- Dieses SQL in Supabase SQL Editor ausführen.

-- Device-Tokens für Push-Benachrichtigungen
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    token TEXT NOT NULL UNIQUE,
    player_name TEXT DEFAULT 'Unknown',
    platform TEXT DEFAULT 'ios',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Calls (History / Deduplizierung)
CREATE TABLE IF NOT EXISTS calls (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT DEFAULT 'Deff-Call',
    target_x INTEGER NOT NULL,
    target_y INTEGER NOT NULL,
    arrival TIMESTAMPTZ NOT NULL,
    link TEXT,
    crop_limit INTEGER,
    discord_message_id TEXT UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index für schnelle Token-Abfragen
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON device_tokens(token);

-- Index für Discord-Message-Deduplizierung
CREATE INDEX IF NOT EXISTS idx_calls_discord_msg ON calls(discord_message_id);
