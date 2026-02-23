-- ============================================================
-- 007_fix_profiles_rls_recursion.sql
-- Fix: Infinite recursion in profiles RLS policy
--
-- Problem: "Kingdom-Mitglieder lesen" macht SELECT auf profiles
-- innerhalb einer profiles-Policy → unendliche Rekursion.
-- Loesung: Hilfsfunktion die mit SECURITY DEFINER RLS umgeht.
-- ============================================================

-- 1) Alte rekursive Policy entfernen
DROP POLICY IF EXISTS "Kingdom-Mitglieder lesen" ON profiles;

-- 2) Hilfsfunktion: Eigene kingdom_id holen (umgeht RLS)
CREATE OR REPLACE FUNCTION public.get_my_kingdom_id()
RETURNS INT AS $$
    SELECT kingdom_id FROM public.profiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE SET search_path = public;

-- 3) Neue Policy ohne Rekursion
CREATE POLICY "Kingdom-Mitglieder lesen"
    ON profiles FOR SELECT
    USING (kingdom_id = public.get_my_kingdom_id());
