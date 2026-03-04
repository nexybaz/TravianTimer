-- ============================================================
-- Kingdom-Mitglieder dürfen Dörfer anderer Kingdom-Mitglieder lesen
-- (für Einsatzplaner: Angreifer-Dorf aus Kingdom wählen)
-- ============================================================

CREATE POLICY "Kingdom-Doerfer lesen"
    ON villages FOR SELECT
    USING (
        user_id IN (
            SELECT id FROM profiles
            WHERE kingdom_id = public.get_my_kingdom_id()
        )
    );
