-- ============================================================
-- 004_cron.sql
-- TravianTimer v2 — pg_cron Jobs
-- VORAUSSETZUNG: pg_cron Extension muss im Supabase Dashboard
-- unter Database → Extensions aktiviert sein!
-- ============================================================

-- ============================================================
-- 1. Calls automatisch auf 'inactive' setzen (jede Minute)
--    Wenn arrival-Zeitpunkt erreicht → Call ist nicht mehr offen
-- ============================================================
SELECT cron.schedule(
    'inactive-calls',
    '* * * * *',
    $$
    UPDATE calls
    SET status = 'inactive'
    WHERE status = 'open'
    AND arrival < now();
    $$
);

-- ============================================================
-- 2. Archivierte Calls aufraeumen (taeglich um 03:00 UTC)
--    Calls die seit 90 Tagen archiviert sind werden geloescht.
--    CASCADE loescht zugehoerige Pledges automatisch.
-- ============================================================
SELECT cron.schedule(
    'cleanup-archived',
    '0 3 * * *',
    $$
    DELETE FROM calls
    WHERE status = 'archived'
    AND updated_at < now() - INTERVAL '90 days';
    $$
);

-- ============================================================
-- 3. Webhook-Failures aufraeumen (woechentlich Sonntag 04:00 UTC)
--    Eintraege aelter als 30 Tage loeschen
-- ============================================================
SELECT cron.schedule(
    'cleanup-webhooks',
    '0 4 * * 0',
    $$
    DELETE FROM webhook_failures
    WHERE created_at < now() - INTERVAL '30 days';
    $$
);

-- ============================================================
-- 4. Alte Troop-Snapshots aufraeumen (monatlich, 1. um 05:00 UTC)
--    Snapshots aelter als 365 Tage loeschen
-- ============================================================
SELECT cron.schedule(
    'cleanup-snapshots',
    '0 5 1 * *',
    $$
    DELETE FROM troop_snapshots
    WHERE created_at < now() - INTERVAL '365 days';
    $$
);
