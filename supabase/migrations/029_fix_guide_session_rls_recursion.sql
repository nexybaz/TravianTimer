-- ============================================================
-- Fix: RLS-Rekursion auf guide_session_members
-- Die SELECT-Policy referenzierte sich selbst → infinite recursion.
-- Lösung: SECURITY DEFINER Funktion die RLS umgeht.
-- ============================================================

-- Hilfsfunktion: Gibt session_ids zurueck, in denen der aktuelle User Mitglied ist.
-- SECURITY DEFINER = laeuft mit den Rechten des Erstellers (umgeht RLS).
CREATE OR REPLACE FUNCTION get_user_guide_sessions()
RETURNS SETOF UUID AS $$
    SELECT session_id
    FROM guide_session_members
    WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================
-- Alte Policies droppen und mit Funktion neu erstellen
-- ============================================================

-- guide_session_members
DROP POLICY IF EXISTS "Mitglieder lesen" ON guide_session_members;

CREATE POLICY "Mitglieder lesen"
    ON guide_session_members FOR SELECT
    USING (session_id IN (SELECT get_user_guide_sessions()));

-- guide_sessions (die Member-basierte Policy)
DROP POLICY IF EXISTS "Session-Mitglieder lesen Sessions" ON guide_sessions;

CREATE POLICY "Session-Mitglieder lesen Sessions"
    ON guide_sessions FOR SELECT
    USING (id IN (SELECT get_user_guide_sessions()));

-- guide_session_progress
DROP POLICY IF EXISTS "Progress lesen" ON guide_session_progress;
DROP POLICY IF EXISTS "Progress erstellen" ON guide_session_progress;
DROP POLICY IF EXISTS "Progress loeschen" ON guide_session_progress;

CREATE POLICY "Progress lesen"
    ON guide_session_progress FOR SELECT
    USING (session_id IN (SELECT get_user_guide_sessions()));

CREATE POLICY "Progress erstellen"
    ON guide_session_progress FOR INSERT
    WITH CHECK (session_id IN (SELECT get_user_guide_sessions()));

CREATE POLICY "Progress loeschen"
    ON guide_session_progress FOR DELETE
    USING (session_id IN (SELECT get_user_guide_sessions()));
