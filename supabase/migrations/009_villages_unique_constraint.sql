-- ============================================================
-- 009_villages_unique_constraint.sql
-- Unique Index auf (user_id, travian_village_id) fuer UPSERT
-- Wird von den Edge Functions verify-player und fetch-world-data benoetigt
-- ============================================================

CREATE UNIQUE INDEX IF NOT EXISTS idx_villages_travian_id
    ON villages(user_id, travian_village_id)
    WHERE travian_village_id IS NOT NULL;
