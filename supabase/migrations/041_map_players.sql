-- ============================================================
-- Map Players: Alle Spieler einer Spielwelt (aus Travian API)
-- Wird beim taeglichen fetch-world-data befuellt
-- Fuer Einsatzplaner: Ziel-Auswahl (Gegner-Koenigreiche)
-- ============================================================

CREATE TABLE IF NOT EXISTS map_players (
    world_id            TEXT NOT NULL,
    travian_player_id   INT NOT NULL,
    player_name         TEXT NOT NULL,
    kingdom_id          INT,
    kingdom_tag         TEXT,
    villages            JSONB DEFAULT '[]'::jsonb,
    updated_at          TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (world_id, travian_player_id)
);

-- Oeffentliche Kartendaten — jeder eingeloggte User kann lesen
ALTER TABLE map_players ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Map-Daten lesen"
    ON map_players FOR SELECT
    USING (auth.uid() IS NOT NULL);
