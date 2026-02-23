-- ============================================================
-- 001_schema.sql
-- TravianTimer v2 — Datenbank-Schema
-- Tabellen, Indexes, Trigger
-- ============================================================

-- ============================================================
-- PROFILES — Spieler-Profile (1:1 mit auth.users)
-- ============================================================
CREATE TABLE profiles (
    id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    player_name       TEXT NOT NULL,
    tribe             TEXT NOT NULL DEFAULT 'Gallier',
    world_id          TEXT,
    world_speed       TEXT DEFAULT 'x1',
    role              TEXT NOT NULL DEFAULT 'player',   -- 'player' | 'caller' | 'admin'
    is_verified       BOOLEAN DEFAULT false,            -- Travian-Account verifiziert?
    travian_player_id INT,                              -- Spieler-ID aus Travian-API
    kingdom_id        INT,                              -- Kingdom-ID aus Travian-API
    kingdom_tag       TEXT,                             -- Kingdom-Tag (z.B. "~WK~")
    created_at        TIMESTAMPTZ DEFAULT now(),
    updated_at        TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- VILLAGES — Doerfer pro Spieler
-- ============================================================
CREATE TABLE villages (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    x               INT NOT NULL,
    y               INT NOT NULL,
    allowed_troops  TEXT[] DEFAULT '{}',         -- Ausgewaehlte Truppentypen
    troop_counts    JSONB DEFAULT '{}',          -- { "gauls.phalanx": 500, ... }
    travian_village_id INT,                      -- Village-ID aus Travian-API
    population      INT,
    is_city         BOOLEAN DEFAULT false,
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- CALLS — Deff-Calls
-- ============================================================
CREATE TABLE calls (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_by          UUID NOT NULL REFERENCES profiles(id),
    kingdom_id          INT,                                    -- Kingdom-Scoping
    title               TEXT NOT NULL,
    target_x            INT NOT NULL,
    target_y            INT NOT NULL,
    arrival             TIMESTAMPTZ NOT NULL,
    link                TEXT,
    crop_limit          INT,
    crop_pledged_total  INT NOT NULL DEFAULT 0,                 -- Aktuelle Getreide-Summe
    status              TEXT NOT NULL DEFAULT 'open',            -- 'open' | 'inactive' | 'archived'
    discord_channel_id  TEXT,                                    -- Discord Channel des Calls
    discord_message_id  TEXT,                                    -- Message-ID des Original-Posts
    created_at          TIMESTAMPTZ DEFAULT now(),
    updated_at          TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- PLEDGES — Truppen-Zusicherungen (Realtime aktiviert)
-- ============================================================
CREATE TABLE pledges (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    call_id         UUID NOT NULL REFERENCES calls(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES profiles(id),
    player_name     TEXT NOT NULL,
    village_name    TEXT NOT NULL,
    village_x       INT NOT NULL,
    village_y       INT NOT NULL,
    troop_kind      TEXT NOT NULL,
    count           INT NOT NULL,
    pledged_at      TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- DEVICE_TOKENS — APNs Push-Tokens
-- ============================================================
CREATE TABLE device_tokens (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    token       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- TROOP_SNAPSHOTS — Truppen-History pro Spieler
-- ============================================================
CREATE TABLE troop_snapshots (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    date            TIMESTAMPTZ NOT NULL,
    village_name    TEXT NOT NULL,
    village_x       INT NOT NULL,
    village_y       INT NOT NULL,
    troop_counts    JSONB NOT NULL DEFAULT '{}',     -- { "gauls.phalanx": 500, ... }
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- GAMEWORLDS — Cache fuer Travian-API Weltdaten (nur Metadaten)
-- ============================================================
CREATE TABLE gameworlds (
    world_id        TEXT PRIMARY KEY,
    speed           INT NOT NULL DEFAULT 1,
    speed_troops    INT NOT NULL DEFAULT 1,
    last_fetched    TIMESTAMPTZ DEFAULT now()
);
-- HINWEIS: Kein players_json! Spielerdaten werden NICHT gecacht,
-- sondern bei Verifizierung direkt in profiles/villages geschrieben.

-- ============================================================
-- DISCORD_CHANNELS — Mapping Discord-Channel -> Kingdom
-- ============================================================
CREATE TABLE discord_channels (
    discord_channel_id  TEXT PRIMARY KEY,
    kingdom_id          INT NOT NULL,
    guild_name          TEXT,                    -- Discord Server-Name (informativ)
    created_at          TIMESTAMPTZ DEFAULT now()
);

-- ============================================================
-- WEBHOOK_FAILURES — Dead-Letter Queue fuer fehlgeschlagene Webhooks
-- ============================================================
CREATE TABLE webhook_failures (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    function    TEXT NOT NULL,           -- z.B. 'pledge-to-discord'
    payload     JSONB NOT NULL,
    error       TEXT,
    created_at  TIMESTAMPTZ DEFAULT now()
);


-- ============================================================
-- INDEXES — Performance-Indexes fuer haeufige Queries
-- ============================================================
CREATE INDEX idx_pledges_call_id          ON pledges(call_id);
CREATE INDEX idx_calls_kingdom_id         ON calls(kingdom_id);
CREATE INDEX idx_calls_status             ON calls(status);
CREATE INDEX idx_calls_kingdom_status     ON calls(kingdom_id, status);
CREATE INDEX idx_villages_user_id         ON villages(user_id);
CREATE INDEX idx_snapshots_user_id        ON troop_snapshots(user_id);
CREATE INDEX idx_snapshots_date           ON troop_snapshots(user_id, date DESC);
CREATE INDEX idx_device_tokens_user       ON device_tokens(user_id);
CREATE INDEX idx_discord_channels_kingdom ON discord_channels(kingdom_id);


-- ============================================================
-- TRIGGER: Auto-Update updated_at
-- ============================================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at_profiles
    BEFORE UPDATE ON profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_calls
    BEFORE UPDATE ON calls FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER set_updated_at_villages
    BEFORE UPDATE ON villages FOR EACH ROW EXECUTE FUNCTION update_updated_at();


-- ============================================================
-- TRIGGER: Auto-Profil bei neuem User
-- ============================================================
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO profiles (id, player_name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'player_name', 'Spieler'));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION handle_new_user();
