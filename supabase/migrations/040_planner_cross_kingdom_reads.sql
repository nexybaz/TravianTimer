-- ============================================================
-- Planer (Duke/ViceKing/King/Admin) duerfen alle Profile und
-- Doerfer lesen — noetig fuer Ziel-Auswahl im Einsatzplaner
-- ============================================================

-- Planer koennen alle Doerfer lesen (auch feindliche Koenigreiche)
CREATE POLICY "Planer lesen alle Doerfer"
    ON villages FOR SELECT
    USING (
        public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    );

-- Planer koennen alle Profile lesen (fuer Kingdom/Spieler-Auswahl)
CREATE POLICY "Planer lesen alle Profile"
    ON profiles FOR SELECT
    USING (
        public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    );
