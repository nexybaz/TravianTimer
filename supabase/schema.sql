-- TravianTimer: Datenbank-Schema
-- Dieses SQL in Supabase SQL Editor ausführen.

-- Device-Tokens für Push-Benachrichtigungen
CREATE TABLE IF NOT EXISTS device_tokens (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    token TEXT NOT NULL UNIQUE,
    player_name TEXT DEFAULT 'Unknown',
    platform TEXT DEFAULT 'ios',
    user_id UUID,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Calls (History / Deduplizierung / Cloud-Sync)
CREATE TABLE IF NOT EXISTS calls (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    title TEXT DEFAULT 'Deff-Call',
    target_x INTEGER NOT NULL,
    target_y INTEGER NOT NULL,
    arrival TIMESTAMPTZ NOT NULL,
    link TEXT,
    crop_limit INTEGER,
    discord_message_id TEXT UNIQUE,
    status TEXT DEFAULT 'open',
    device_token TEXT,
    user_id UUID,
    guild_id TEXT,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Pledges (Truppen-Zusagen pro Call)
CREATE TABLE IF NOT EXISTS pledges (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    call_id UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    player_name TEXT NOT NULL,
    village_name TEXT NOT NULL,
    village_x INTEGER NOT NULL,
    village_y INTEGER NOT NULL,
    troop_kind TEXT NOT NULL,
    count INTEGER NOT NULL DEFAULT 0,
    pledged_at TIMESTAMPTZ DEFAULT now(),
    user_id UUID
);

-- Tombstones für gelöschte Calls (Multi-Device Sync)
CREATE TABLE IF NOT EXISTS deleted_calls (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    call_id UUID NOT NULL,
    user_id UUID NOT NULL,
    deleted_at TIMESTAMPTZ DEFAULT now()
);

-- Team-Members Mapping (User <-> Discord Guild)
CREATE TABLE IF NOT EXISTS team_members (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    guild_id TEXT NOT NULL,
    joined_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, guild_id)
);

-- Indices
CREATE INDEX IF NOT EXISTS idx_device_tokens_token ON device_tokens(token);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user_id ON device_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_calls_discord_msg ON calls(discord_message_id);
CREATE INDEX IF NOT EXISTS idx_calls_device_token ON calls(device_token);
CREATE INDEX IF NOT EXISTS idx_calls_user_id ON calls(user_id);
CREATE INDEX IF NOT EXISTS idx_calls_guild_id ON calls(guild_id);
CREATE INDEX IF NOT EXISTS idx_pledges_call_id ON pledges(call_id);
CREATE INDEX IF NOT EXISTS idx_pledges_user_id ON pledges(user_id);
CREATE INDEX IF NOT EXISTS idx_deleted_calls_user_id ON deleted_calls(user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_user_id ON team_members(user_id);
CREATE INDEX IF NOT EXISTS idx_team_members_guild_id ON team_members(guild_id);
