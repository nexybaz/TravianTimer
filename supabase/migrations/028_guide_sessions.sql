-- ============================================================
-- Kollaborative Guide-Sessions (max 3 Spieler, gemeinsame Checkliste)
-- ============================================================

-- Join-Code Zeichensatz (ohne verwechselbare: O/0/I/1/L)
CREATE OR REPLACE FUNCTION generate_join_code()
RETURNS TEXT AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    code  TEXT := '';
    i     INT;
BEGIN
    LOOP
        code := '';
        FOR i IN 1..4 LOOP
            code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
        END LOOP;
        -- Prüfe ob Code schon existiert
        IF NOT EXISTS (SELECT 1 FROM guide_sessions WHERE join_code = code) THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Sessions
CREATE TABLE guide_sessions (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    join_code    TEXT NOT NULL UNIQUE DEFAULT generate_join_code(),
    guide_type   TEXT NOT NULL DEFAULT 'schnellsiedel',
    created_by   UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    created_at   TIMESTAMPTZ DEFAULT now()
);

-- Mitglieder
CREATE TABLE guide_session_members (
    session_id   UUID NOT NULL REFERENCES guide_sessions(id) ON DELETE CASCADE,
    user_id      UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    joined_at    TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (session_id, user_id)
);

-- Gemeinsamer Fortschritt
CREATE TABLE guide_session_progress (
    session_id   UUID NOT NULL REFERENCES guide_sessions(id) ON DELETE CASCADE,
    step_id      TEXT NOT NULL,
    checked_by   UUID REFERENCES profiles(id),
    checked_at   TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (session_id, step_id)
);

-- ============================================================
-- Max 3 Mitglieder pro Session (Trigger)
-- ============================================================

CREATE OR REPLACE FUNCTION check_max_session_members()
RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT COUNT(*) FROM guide_session_members WHERE session_id = NEW.session_id) >= 3 THEN
        RAISE EXCEPTION 'Session ist voll (max. 3 Spieler)';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER enforce_max_session_members
    BEFORE INSERT ON guide_session_members
    FOR EACH ROW
    EXECUTE FUNCTION check_max_session_members();

-- ============================================================
-- RLS
-- ============================================================

ALTER TABLE guide_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE guide_session_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE guide_session_progress ENABLE ROW LEVEL SECURITY;

-- Sessions: Mitglieder duerfen lesen
CREATE POLICY "Session-Mitglieder lesen Sessions"
    ON guide_sessions FOR SELECT
    USING (
        id IN (SELECT session_id FROM guide_session_members WHERE user_id = auth.uid())
    );

-- Sessions: Jeder darf erstellen (wird automatisch Mitglied)
CREATE POLICY "Sessions erstellen"
    ON guide_sessions FOR INSERT
    WITH CHECK (created_by = auth.uid());

-- Sessions: Creator darf loeschen
CREATE POLICY "Eigene Sessions loeschen"
    ON guide_sessions FOR DELETE
    USING (created_by = auth.uid());

-- Sessions: Jeder darf per join_code suchen (fuer Beitritt)
CREATE POLICY "Sessions per Code finden"
    ON guide_sessions FOR SELECT
    USING (true);

-- Mitglieder: Session-Mitglieder duerfen alle Mitglieder sehen
CREATE POLICY "Mitglieder lesen"
    ON guide_session_members FOR SELECT
    USING (
        session_id IN (SELECT session_id FROM guide_session_members WHERE user_id = auth.uid())
    );

-- Mitglieder: Jeder darf sich selbst hinzufuegen
CREATE POLICY "Selbst beitreten"
    ON guide_session_members FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Mitglieder: Jeder darf sich selbst entfernen
CREATE POLICY "Selbst verlassen"
    ON guide_session_members FOR DELETE
    USING (user_id = auth.uid());

-- Progress: Mitglieder duerfen lesen
CREATE POLICY "Progress lesen"
    ON guide_session_progress FOR SELECT
    USING (
        session_id IN (SELECT session_id FROM guide_session_members WHERE user_id = auth.uid())
    );

-- Progress: Mitglieder duerfen erstellen
CREATE POLICY "Progress erstellen"
    ON guide_session_progress FOR INSERT
    WITH CHECK (
        session_id IN (SELECT session_id FROM guide_session_members WHERE user_id = auth.uid())
    );

-- Progress: Mitglieder duerfen loeschen (Checkbox abhaken/aufheben)
CREATE POLICY "Progress loeschen"
    ON guide_session_progress FOR DELETE
    USING (
        session_id IN (SELECT session_id FROM guide_session_members WHERE user_id = auth.uid())
    );

-- ============================================================
-- Indexes
-- ============================================================

CREATE INDEX idx_guide_session_members_user ON guide_session_members(user_id);
CREATE INDEX idx_guide_session_members_session ON guide_session_members(session_id);
CREATE INDEX idx_guide_session_progress_session ON guide_session_progress(session_id);

-- ============================================================
-- Realtime
-- ============================================================

ALTER PUBLICATION supabase_realtime ADD TABLE guide_session_progress;
ALTER PUBLICATION supabase_realtime ADD TABLE guide_session_members;
