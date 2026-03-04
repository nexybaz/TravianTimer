-- ============================================
-- 044: Dorfplaene pro User (Cloud Sync)
-- ============================================
-- Speichert alle VillagePlans eines Users als
-- JSONB-Array. 1:1 Pattern von avatar_configs.
-- ============================================

CREATE TABLE IF NOT EXISTS village_plans_sync (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    plans       JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

ALTER TABLE village_plans_sync ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Village-Plans lesen"
    ON village_plans_sync FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Eigene Village-Plans erstellen"
    ON village_plans_sync FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Eigene Village-Plans aktualisieren"
    ON village_plans_sync FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Eigene Village-Plans loeschen"
    ON village_plans_sync FOR DELETE USING (user_id = auth.uid());

CREATE INDEX idx_village_plans_sync_user ON village_plans_sync(user_id);
