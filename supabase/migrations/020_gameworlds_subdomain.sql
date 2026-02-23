-- ============================================================
-- 020_gameworlds_subdomain.sql
-- Subdomain-Spalte fuer Gameworlds
-- Die API-URL nutzt die Subdomain: https://<subdomain>.kingdoms.com/api/...
-- Bei den meisten Welten ist subdomain = world_id (z.B. de1n -> de1n),
-- aber manche weichen ab (z.B. ae1n -> arabia1n).
-- ============================================================

ALTER TABLE gameworlds ADD COLUMN IF NOT EXISTS subdomain TEXT;

-- Default: subdomain = world_id (fuer bestehende Eintraege)
UPDATE gameworlds SET subdomain = world_id WHERE subdomain IS NULL;
