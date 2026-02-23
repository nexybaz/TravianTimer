-- Tool-Favoriten pro User
CREATE TABLE IF NOT EXISTS tool_favorites (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    tool_id     TEXT NOT NULL,
    created_at  TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id, tool_id)
);

ALTER TABLE tool_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Favoriten lesen"
    ON tool_favorites FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Favoriten erstellen"
    ON tool_favorites FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Eigene Favoriten loeschen"
    ON tool_favorites FOR DELETE
    USING (user_id = auth.uid());

CREATE INDEX idx_tool_favorites_user ON tool_favorites(user_id);
