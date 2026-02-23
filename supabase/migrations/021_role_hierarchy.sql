-- ============================================================
-- 021_role_hierarchy.sql
-- Rollen-System von 3 auf 5 Rollen umstellen (Travian-Hierarchie).
-- Alte Rollen:  player | caller | admin
-- Neue Rollen:  governor | duke | viceking | king | admin
--
-- Mapping:
--   player  → governor  (Statthalter)
--   caller  → duke      (Herzog)
--   admin   → admin     (bleibt)
-- Neue Rollen viceking (Vize-Koenig) + king (Koenig) werden hinzugefuegt.
--
-- Die Rolle wird kuenftig automatisch aus der Travian API gesetzt
-- (player.role: 0=governor, 1=duke, 2=viceking, 3=king).
-- ============================================================

-- 1. Bestehende Rollen migrieren
UPDATE profiles SET role = 'governor' WHERE role = 'player';
UPDATE profiles SET role = 'duke'     WHERE role = 'caller';
-- admin bleibt admin
-- Bot-System-User (Discord-Bot) von caller → duke
UPDATE profiles SET role = 'duke' WHERE id = '00000000-0000-0000-0000-000000000001'::UUID AND role = 'caller';

-- 2. Default fuer neue Spieler anpassen
ALTER TABLE profiles ALTER COLUMN role SET DEFAULT 'governor';

-- 3. RLS-Policies aktualisieren (neue Rollennamen)

-- Calls erstellen: ab Herzog (duke, viceking, king, admin)
DROP POLICY IF EXISTS "Call erstellen" ON calls;
CREATE POLICY "Call erstellen"
    ON calls FOR INSERT
    WITH CHECK (
        created_by = auth.uid()
        AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    );

-- Calls Status aendern: ab Herzog
DROP POLICY IF EXISTS "Call-Status aendern" ON calls;
CREATE POLICY "Call-Status aendern"
    ON calls FOR UPDATE
    USING (
        created_by = auth.uid()
        OR public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    );

-- Calls loeschen: ab Koenig
DROP POLICY IF EXISTS "Admin Calls loeschen" ON calls;
CREATE POLICY "Calls loeschen"
    ON calls FOR DELETE
    USING (public.get_my_role() IN ('king', 'admin'));

-- Rollen verwalten: ab Koenig
DROP POLICY IF EXISTS "Admin aendert Rollen" ON profiles;
CREATE POLICY "Rollen verwalten"
    ON profiles FOR UPDATE
    USING (
        public.get_my_role() IN ('king', 'admin')
        AND kingdom_id IS NOT NULL
        AND kingdom_id = public.get_my_kingdom_id()
    )
    WITH CHECK (
        public.get_my_role() IN ('king', 'admin')
        AND kingdom_id IS NOT NULL
        AND kingdom_id = public.get_my_kingdom_id()
    );
