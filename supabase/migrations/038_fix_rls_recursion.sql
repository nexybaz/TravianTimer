-- ============================================================
-- Fix: Infinite RLS recursion zwischen operations <-> operation_members
--
-- Problem: operations SELECT -> liest operation_members
--          operation_members SELECT -> liest operations -> Endlosschleife
--
-- Lösung: SECURITY DEFINER Hilfsfunktion die RLS umgeht
-- ============================================================

-- Hilfsfunktion: Prüft ob User Mitglied einer Operation ist (umgeht RLS)
CREATE OR REPLACE FUNCTION is_operation_member(op_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM operation_members
        WHERE operation_id = op_id AND user_id = auth.uid()
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- Hilfsfunktion: Prüft ob User Zugriff auf eine Operation hat (umgeht RLS)
CREATE OR REPLACE FUNCTION can_access_operation(op_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    op RECORD;
BEGIN
    SELECT kingdom_id, created_by INTO op
    FROM operations WHERE id = op_id;

    IF NOT FOUND THEN RETURN FALSE; END IF;

    -- Creator hat immer Zugriff
    IF op.created_by = auth.uid() THEN RETURN TRUE; END IF;

    -- Gleiches Kingdom
    IF op.kingdom_id IS NOT NULL AND op.kingdom_id = public.get_my_kingdom_id() THEN RETURN TRUE; END IF;

    -- Mitglied via Join-Code
    IF EXISTS (SELECT 1 FROM operation_members WHERE operation_id = op_id AND user_id = auth.uid()) THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ============================================================
-- Operations: Policy neu mit Funktion statt Subquery
-- ============================================================
DROP POLICY IF EXISTS "Operations lesen" ON operations;
CREATE POLICY "Operations lesen"
    ON operations FOR SELECT
    USING (
        created_by = auth.uid()
        OR kingdom_id = public.get_my_kingdom_id()
        OR is_operation_member(id)
    );

-- ============================================================
-- Operation Members: Einfache Policy ohne operations-Referenz
-- ============================================================
DROP POLICY IF EXISTS "Operation Members lesen" ON operation_members;
CREATE POLICY "Operation Members lesen"
    ON operation_members FOR SELECT
    USING (
        user_id = auth.uid()
        OR can_access_operation(operation_id)
    );

-- ============================================================
-- Planned Attacks: Policies mit Funktion statt Subquery
-- ============================================================
DROP POLICY IF EXISTS "Planned Attacks lesen" ON planned_attacks;
CREATE POLICY "Planned Attacks lesen"
    ON planned_attacks FOR SELECT
    USING (can_access_operation(operation_id));

DROP POLICY IF EXISTS "Planned Attacks erstellen" ON planned_attacks;
CREATE POLICY "Planned Attacks erstellen"
    ON planned_attacks FOR INSERT
    WITH CHECK (
        operation_id IN (
            SELECT id FROM operations
            WHERE created_by = auth.uid()
               OR (kingdom_id = public.get_my_kingdom_id()
                   AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin'))
        )
    );

DROP POLICY IF EXISTS "Planned Attacks aendern" ON planned_attacks;
CREATE POLICY "Planned Attacks aendern"
    ON planned_attacks FOR UPDATE
    USING (
        assigned_to = auth.uid()
        OR operation_id IN (
            SELECT id FROM operations
            WHERE created_by = auth.uid()
               OR (kingdom_id = public.get_my_kingdom_id()
                   AND public.get_my_role() IN ('duke', 'viceking', 'king', 'admin'))
        )
    );

DROP POLICY IF EXISTS "Planned Attacks loeschen" ON planned_attacks;
CREATE POLICY "Planned Attacks loeschen"
    ON planned_attacks FOR DELETE
    USING (
        operation_id IN (
            SELECT id FROM operations
            WHERE created_by = auth.uid()
               OR (kingdom_id = public.get_my_kingdom_id()
                   AND public.get_my_role() IN ('king', 'admin'))
        )
    );
