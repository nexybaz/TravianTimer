-- ============================================================
-- 012_admin_update_roles.sql
-- Admin darf Rollen von Kingdom-Mitgliedern aendern.
-- Nutzt die SECURITY DEFINER Hilfsfunktionen aus 007/008.
-- ============================================================

-- Admin kann Profile von Kingdom-Mitgliedern updaten (fuer Rollen-Aenderung)
CREATE POLICY "Admin aendert Rollen"
    ON profiles FOR UPDATE
    USING (
        public.get_my_role() = 'admin'
        AND kingdom_id IS NOT NULL
        AND kingdom_id = public.get_my_kingdom_id()
    )
    WITH CHECK (
        public.get_my_role() = 'admin'
        AND kingdom_id IS NOT NULL
        AND kingdom_id = public.get_my_kingdom_id()
    );
