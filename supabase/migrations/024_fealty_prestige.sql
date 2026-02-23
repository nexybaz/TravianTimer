-- Treue-Level und Prestige-Level am Profil speichern
-- (Kingdoms-Lehnssystem: beeinflusst Baukosten & Bauzeiten)

ALTER TABLE profiles
    ADD COLUMN fealty_level    INT NOT NULL DEFAULT 0,
    ADD COLUMN prestige_level  INT NOT NULL DEFAULT 0;

-- Constraints: Fealty 0–20, Prestige 0–20
ALTER TABLE profiles
    ADD CONSTRAINT chk_fealty_level   CHECK (fealty_level   BETWEEN 0 AND 20),
    ADD CONSTRAINT chk_prestige_level CHECK (prestige_level BETWEEN 0 AND 20);
