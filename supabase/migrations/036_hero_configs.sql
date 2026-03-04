-- Hero-Konfiguration pro User (1 Eintrag)
CREATE TABLE IF NOT EXISTS hero_configs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    level       INT NOT NULL DEFAULT 1,
    skill_fight INT NOT NULL DEFAULT 0,
    skill_off   INT NOT NULL DEFAULT 0,
    skill_def   INT NOT NULL DEFAULT 0,
    skill_res   INT NOT NULL DEFAULT 0,
    hp          INT NOT NULL DEFAULT 100,
    xp          INT NOT NULL DEFAULT 0,
    equipment   JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

ALTER TABLE hero_configs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Eigene Hero-Config lesen"
    ON hero_configs FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Hero-Config erstellen"
    ON hero_configs FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Eigene Hero-Config aktualisieren"
    ON hero_configs FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Hero-Config loeschen"
    ON hero_configs FOR DELETE
    USING (user_id = auth.uid());

CREATE INDEX idx_hero_configs_user ON hero_configs(user_id);
