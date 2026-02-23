-- ============================================================
-- Guide-Session Mitglieder duerfen sich gegenseitig sehen
-- Ohne diese Policy zeigt der profiles-Join nur "Spieler" an,
-- wenn die Mitglieder nicht im selben Kingdom sind.
-- ============================================================

CREATE POLICY "Guide-Session Mitglieder lesen"
    ON profiles FOR SELECT
    USING (
        id IN (
            SELECT gsm.user_id
            FROM guide_session_members gsm
            WHERE gsm.session_id IN (SELECT get_user_guide_sessions())
        )
    );
