-- ============================================================
-- 019_fix_villages_unique_constraint.sql
-- Fix: Partieller UNIQUE INDEX reicht nicht fuer PostgREST UPSERT.
-- PostgREST benoetigt einen echten UNIQUE CONSTRAINT.
-- ============================================================

-- Alten partiellen Index entfernen
DROP INDEX IF EXISTS idx_villages_travian_id;

-- Echten UNIQUE Constraint erstellen (nicht partiell)
-- Fuer Villages mit travian_village_id verwenden wir einen Constraint.
-- Villages ohne travian_village_id (manuell angelegt) haben NULL und
-- werden von UNIQUE ignoriert (NULL != NULL in SQL).
ALTER TABLE villages
    ADD CONSTRAINT uq_villages_user_travian_id
    UNIQUE (user_id, travian_village_id);
