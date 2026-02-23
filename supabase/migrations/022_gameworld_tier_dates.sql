-- ============================================================
-- 022_gameworld_tier_dates.sql
-- Tier-Daten fuer Helden-Gegenstaende pro Spielwelt.
-- Quelle: https://blog.kingdoms.com/de/game-world-calendar/
--
-- start_date  = Stufe 1 (ab Start verfuegbar)
-- tier2_date  = Stufe 2 Gegenstaende freigeschaltet
-- tier3_date  = Stufe 3 Gegenstaende freigeschaltet
--
-- Die aktuelle Stufe wird in der App berechnet:
--   heute >= tier3_date → Stufe 3
--   heute >= tier2_date → Stufe 2
--   sonst              → Stufe 1
-- ============================================================

ALTER TABLE gameworlds ADD COLUMN IF NOT EXISTS start_date DATE;
ALTER TABLE gameworlds ADD COLUMN IF NOT EXISTS tier2_date DATE;
ALTER TABLE gameworlds ADD COLUMN IF NOT EXISTS tier3_date DATE;
