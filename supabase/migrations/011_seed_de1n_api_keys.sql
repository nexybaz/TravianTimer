-- ============================================================
-- 011_seed_de1n_api_keys.sql
-- API-Keys fuer de1n Spielwelt eintragen
-- ============================================================

INSERT INTO gameworlds (world_id, private_api_key, public_site_key, speed, speed_troops)
VALUES ('de1n', 'aea506acd7e3e6100d9b253f779cb17c', '6bcd475b455016318d11b99e65359262', 1, 1)
ON CONFLICT (world_id) DO UPDATE SET
    private_api_key = EXCLUDED.private_api_key,
    public_site_key = EXCLUDED.public_site_key;
