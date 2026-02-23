-- Prestige: statt Level speichern wir die Gesamtpunktzahl,
-- das Level wird in der App daraus berechnet.

ALTER TABLE profiles DROP CONSTRAINT IF EXISTS chk_prestige_level;
ALTER TABLE profiles RENAME COLUMN prestige_level TO prestige_points;
ALTER TABLE profiles ALTER COLUMN prestige_points SET DEFAULT 0;
ALTER TABLE profiles ADD CONSTRAINT chk_prestige_points CHECK (prestige_points >= 0);
