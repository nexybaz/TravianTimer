-- ============================================================
-- 008_fix_all_rls_subselects.sql
-- Alle RLS-Policies die profiles abfragen nutzen jetzt
-- die SECURITY DEFINER Hilfsfunktionen statt Sub-Selects.
-- Verhindert potentielle Rekursion und ist performanter.
-- ============================================================

-- Hilfsfunktion: Eigene Rolle holen (umgeht RLS auf profiles)
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- ============================================================
-- CALLS: Policies neu erstellen mit Hilfsfunktionen
-- ============================================================

DROP POLICY IF EXISTS "Kingdom-Calls lesen" ON calls;
CREATE POLICY "Kingdom-Calls lesen"
    ON calls FOR SELECT
    USING (kingdom_id = public.get_my_kingdom_id());

DROP POLICY IF EXISTS "Call erstellen" ON calls;
CREATE POLICY "Call erstellen"
    ON calls FOR INSERT
    WITH CHECK (
        created_by = auth.uid()
        AND public.get_my_role() IN ('caller', 'admin')
    );

DROP POLICY IF EXISTS "Call-Status aendern" ON calls;
CREATE POLICY "Call-Status aendern"
    ON calls FOR UPDATE
    USING (
        created_by = auth.uid()
        OR public.get_my_role() IN ('caller', 'admin')
    );

DROP POLICY IF EXISTS "Admin Calls loeschen" ON calls;
CREATE POLICY "Admin Calls loeschen"
    ON calls FOR DELETE
    USING (public.get_my_role() = 'admin');

-- ============================================================
-- PLEDGES: Kingdom-Pledges lesen mit Hilfsfunktion
-- ============================================================

DROP POLICY IF EXISTS "Kingdom-Pledges lesen" ON pledges;
CREATE POLICY "Kingdom-Pledges lesen"
    ON pledges FOR SELECT
    USING (
        call_id IN (
            SELECT id FROM calls
            WHERE kingdom_id = public.get_my_kingdom_id()
        )
    );
