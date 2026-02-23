-- ============================================================
-- 013_replica_identity_full.sql
-- TravianTimer — REPLICA IDENTITY FULL fuer Realtime DELETE
-- Ohne FULL sendet Postgres bei DELETE nur die Primary Key,
-- nicht die kompletten alten Daten (old_record).
-- ============================================================

ALTER TABLE calls REPLICA IDENTITY FULL;
ALTER TABLE pledges REPLICA IDENTITY FULL;
