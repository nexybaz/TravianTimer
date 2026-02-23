-- ============================================================
-- 003_realtime.sql
-- TravianTimer v2 — Realtime Publications
-- Live-Updates via Supabase Websocket
-- ============================================================

-- Pledges: Live-Updates wenn jemand Truppen zusichert
-- → App zeigt sofort neue/geaenderte Pledges
ALTER PUBLICATION supabase_realtime ADD TABLE pledges;

-- Calls: Live-Updates wenn ein neuer Call erstellt wird
-- → App zeigt sofort neue Calls / Status-Aenderungen
ALTER PUBLICATION supabase_realtime ADD TABLE calls;
