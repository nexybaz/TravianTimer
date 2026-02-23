-- ============================================================
-- 002_rls.sql
-- TravianTimer v2 — Row Level Security Policies
-- ============================================================

-- ============================================================
-- PROFILES
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- Eigenes Profil lesen
CREATE POLICY "Eigenes Profil lesen"
    ON profiles FOR SELECT
    USING (auth.uid() = id);

-- Eigenes Profil aendern
CREATE POLICY "Eigenes Profil aendern"
    ON profiles FOR UPDATE
    USING (auth.uid() = id);

-- Profile im gleichen Kingdom lesen (fuer Rollen-Verwaltung, Mitgliederliste)
CREATE POLICY "Kingdom-Mitglieder lesen"
    ON profiles FOR SELECT
    USING (kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid()));


-- ============================================================
-- VILLAGES
-- ============================================================
ALTER TABLE villages ENABLE ROW LEVEL SECURITY;

-- Eigene Doerfer: lesen, erstellen, aendern, loeschen
CREATE POLICY "Eigene Doerfer"
    ON villages FOR ALL
    USING (user_id = auth.uid());


-- ============================================================
-- CALLS (Kingdom-scoped: nur Mitglieder sehen ihre Calls)
-- ============================================================
ALTER TABLE calls ENABLE ROW LEVEL SECURITY;

-- Calls des eigenen Kingdoms lesen
CREATE POLICY "Kingdom-Calls lesen"
    ON calls FOR SELECT
    USING (
        kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid())
    );

-- Call erstellen (nur caller + admin)
CREATE POLICY "Call erstellen"
    ON calls FOR INSERT
    WITH CHECK (
        created_by = auth.uid()
        AND (SELECT role FROM profiles WHERE id = auth.uid()) IN ('caller', 'admin')
    );

-- Call-Status aendern (eigener Call oder caller/admin)
CREATE POLICY "Call-Status aendern"
    ON calls FOR UPDATE
    USING (
        created_by = auth.uid()
        OR (SELECT role FROM profiles WHERE id = auth.uid()) IN ('caller', 'admin')
    );

-- Calls loeschen (nur admin)
CREATE POLICY "Admin Calls loeschen"
    ON calls FOR DELETE
    USING (
        (SELECT role FROM profiles WHERE id = auth.uid()) = 'admin'
    );


-- ============================================================
-- PLEDGES (Kingdom-scoped ueber den zugehoerigen Call)
-- ============================================================
ALTER TABLE pledges ENABLE ROW LEVEL SECURITY;

-- Pledges des eigenen Kingdoms lesen (via Call-Zuordnung)
CREATE POLICY "Kingdom-Pledges lesen"
    ON pledges FOR SELECT
    USING (
        call_id IN (
            SELECT id FROM calls
            WHERE kingdom_id = (SELECT kingdom_id FROM profiles WHERE id = auth.uid())
        )
    );

-- Eigene Pledges erstellen
CREATE POLICY "Eigene Pledges"
    ON pledges FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- Eigene Pledges aendern
CREATE POLICY "Eigene Pledges aendern"
    ON pledges FOR UPDATE
    USING (user_id = auth.uid());

-- Eigene Pledges loeschen
CREATE POLICY "Eigene Pledges loeschen"
    ON pledges FOR DELETE
    USING (user_id = auth.uid());


-- ============================================================
-- TROOP_SNAPSHOTS
-- ============================================================
ALTER TABLE troop_snapshots ENABLE ROW LEVEL SECURITY;

-- Eigene Snapshots: lesen, erstellen, aendern, loeschen
CREATE POLICY "Eigene Snapshots"
    ON troop_snapshots FOR ALL
    USING (user_id = auth.uid());


-- ============================================================
-- DEVICE_TOKENS
-- ============================================================
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;

-- Eigene Tokens: lesen, erstellen, aendern, loeschen
CREATE POLICY "Eigene Tokens"
    ON device_tokens FOR ALL
    USING (user_id = auth.uid());


-- ============================================================
-- GAMEWORLDS — Alle authentifizierten User duerfen lesen
-- ============================================================
ALTER TABLE gameworlds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Gameworlds lesen"
    ON gameworlds FOR SELECT
    USING (auth.role() = 'authenticated');

-- Schreiben nur via Service Role (Edge Functions)
-- → Kein INSERT/UPDATE Policy fuer anon/authenticated noetig


-- ============================================================
-- DISCORD_CHANNELS — Nur Service Role (Bot) schreibt
-- ============================================================
ALTER TABLE discord_channels ENABLE ROW LEVEL SECURITY;

-- Authentifizierte User duerfen lesen (fuer Kingdom-Anzeige)
CREATE POLICY "Discord Channels lesen"
    ON discord_channels FOR SELECT
    USING (auth.role() = 'authenticated');

-- Schreiben nur via Service Role (Discord Bot)


-- ============================================================
-- WEBHOOK_FAILURES — Nur Service Role
-- ============================================================
ALTER TABLE webhook_failures ENABLE ROW LEVEL SECURITY;

-- Kein Zugriff fuer normale User
-- Nur Service Role Key (Edge Functions, Bot) kann lesen/schreiben
