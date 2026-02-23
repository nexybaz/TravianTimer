-- ============================================================
-- Migration 015: Fix Push Trigger — Hardcoded URL + Anon Key
-- ============================================================
-- Ersetzt den Trigger aus 014 der app.settings brauchte.
-- Nutzt stattdessen hardcoded Supabase URL und Anon Key
-- (beides ist oeffentlich und kann sicher in der DB stehen).
-- Die Edge Function nutzt intern ihren eigenen Service Role Key.
-- ============================================================

CREATE OR REPLACE FUNCTION notify_new_call()
RETURNS TRIGGER AS $$
DECLARE
    request_id BIGINT;
BEGIN
    -- HTTP POST an Edge Function via pg_net
    -- URL und Anon Key sind oeffentlich — kein Sicherheitsrisiko
    SELECT extensions.http_post(
        url := 'https://pnawukicutnnbtkogvnm.supabase.co/functions/v1/push-notification',
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
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBuYXd1a2ljdXRubmJ0a29ndm5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk1NTM3NjksImV4cCI6MjA1NTEyOTc2OX0.r5f0gOPR0WHkfzcTdy-_DVGe_fxVOXzZ1UyUtGiXl6Y'
        )
    ) INTO request_id;

    RAISE NOTICE '[notify_new_call] Push request gesendet: %', request_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger bleibt gleich (wurde in 014 erstellt)
-- DROP TRIGGER IF EXISTS on_new_call_push ON calls;
-- CREATE TRIGGER on_new_call_push
--     AFTER INSERT ON calls
--     FOR EACH ROW
--     EXECUTE FUNCTION notify_new_call();
