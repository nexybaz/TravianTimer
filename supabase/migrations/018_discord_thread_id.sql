-- ============================================================
-- Migration 018: Discord Thread ID fuer Calls
-- ============================================================
-- Wenn ein Call in einem Discord-Thread gepostet wird, speichern wir
-- die Thread-ID damit Pledge-Updates in den richtigen Thread gehen.
-- discord_channel_id bleibt die Parent-Channel-ID (fuer Kingdom-Mapping).
-- ============================================================

ALTER TABLE calls ADD COLUMN IF NOT EXISTS discord_thread_id TEXT;
