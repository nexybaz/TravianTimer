-- ============================================================
-- 010_gameworlds_api_keys.sql
-- API-Keys pro Spielwelt in gameworlds-Tabelle
-- Jede Spielwelt hat eigenen privateApiKey + publicSiteKey
-- ============================================================

-- Neue Spalten fuer API-Keys (nur via Service Role les-/schreibbar)
ALTER TABLE gameworlds ADD COLUMN IF NOT EXISTS private_api_key TEXT;
ALTER TABLE gameworlds ADD COLUMN IF NOT EXISTS public_site_key TEXT;
