-- 023: Spieler-Funktionen (Deffer / Offer / Spaeher)
-- Neben der hierarchischen Rolle bekommt jeder Spieler optional
-- eine oder mehrere Funktionen zugewiesen.

-- Neues TEXT-Array-Feld (leerer Default)
ALTER TABLE profiles ADD COLUMN functions TEXT[] NOT NULL DEFAULT '{}';

-- RLS: Funktionen verwalten (ab Herzog, innerhalb desselben Kingdoms)
CREATE POLICY "Funktionen verwalten" ON profiles FOR UPDATE
USING (
    public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    AND kingdom_id IS NOT NULL
    AND kingdom_id = public.get_my_kingdom_id()
)
WITH CHECK (
    public.get_my_role() IN ('duke', 'viceking', 'king', 'admin')
    AND kingdom_id IS NOT NULL
    AND kingdom_id = public.get_my_kingdom_id()
);
