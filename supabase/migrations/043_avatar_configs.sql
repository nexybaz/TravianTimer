-- ============================================
-- 043: Avatar-Konfiguration pro User
-- ============================================
-- Speichert die Avatar-Generator Einstellungen
-- (Frisur, Augen, Nase, Mund, Schmuck, Farben)
-- als JSONB pro User. 1:1 Pattern von hero_configs.
-- ============================================

CREATE TABLE IF NOT EXISTS avatar_configs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    config      JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

ALTER TABLE avatar_configs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Eigene Avatar-Config lesen"
    ON avatar_configs FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Avatar-Config erstellen"
    ON avatar_configs FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Eigene Avatar-Config aktualisieren"
    ON avatar_configs FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Avatar-Config loeschen"
    ON avatar_configs FOR DELETE
    USING (user_id = auth.uid());

CREATE INDEX idx_avatar_configs_user ON avatar_configs(user_id);
