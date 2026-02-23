-- ============================================================
-- Migration 014: Push Notification Webhook
-- ============================================================
-- Ruft die Edge Function push-notification auf wenn ein neuer Call erstellt wird.
-- Nutzt pg_net Extension fuer HTTP-Requests aus dem Trigger.
-- ============================================================

-- pg_net Extension aktivieren (falls noch nicht aktiv)
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

-- ============================================================
-- Trigger Function: Push-Notification bei neuem Call
-- ============================================================
CREATE OR REPLACE FUNCTION notify_new_call()
RETURNS TRIGGER AS $$
DECLARE
    edge_function_url TEXT;
    service_role_key TEXT;
    request_id BIGINT;
BEGIN
    -- Edge Function URL zusammenbauen
    edge_function_url := current_setting('app.settings.supabase_url', true)
        || '/functions/v1/push-notification';

    -- Service Role Key aus App-Settings lesen
    service_role_key := current_setting('app.settings.service_role_key', true);

    -- Nur wenn konfiguriert (sonst still ueberspringen)
    IF edge_function_url IS NULL OR service_role_key IS NULL THEN
        RAISE NOTICE '[notify_new_call] Edge Function URL oder Service Role Key nicht konfiguriert — Push uebersprungen';
        RETURN NEW;
    END IF;

    -- HTTP POST an Edge Function via pg_net
    SELECT extensions.http_post(
        url := edge_function_url,
        body := jsonb_build_object(
            'call_id', NEW.id,
            'kingdom_id', NEW.kingdom_id,
            'title', NEW.title,
            'target_x', NEW.target_x,
            'target_y', NEW.target_y,
            'created_by', NEW.created_by
        ),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer ' || service_role_key
        )
    ) INTO request_id;

    RAISE NOTICE '[notify_new_call] Push request gesendet: %', request_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Trigger: Nach INSERT auf calls
-- ============================================================
DROP TRIGGER IF EXISTS on_new_call_push ON calls;
CREATE TRIGGER on_new_call_push
    AFTER INSERT ON calls
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_call();

-- ============================================================
-- HINWEIS: Die Edge Function URL und der Service Role Key muessen
-- als Supabase App-Settings konfiguriert werden:
--
-- ALTER DATABASE postgres SET app.settings.supabase_url = 'https://pnawukicutnnbtkogvnm.supabase.co';
-- ALTER DATABASE postgres SET app.settings.service_role_key = 'eyJ...';
--
-- Alternativ: Supabase Dashboard -> Database Webhooks nutzen
-- (grafische Konfiguration statt pg_net Trigger).
-- ============================================================
