-- ============================================================
-- Migration 035: Push Trigger — arrival mitsenden
-- ============================================================
-- Fuegt arrival zum Payload hinzu, damit die Push-Nachricht
-- die Ankunftszeit anzeigen kann statt doppelter Koordinaten.
-- ============================================================

CREATE OR REPLACE FUNCTION notify_new_call()
RETURNS TRIGGER AS $$
DECLARE
    request_id BIGINT;
BEGIN
    SELECT net.http_post(
        url := 'https://pnawukicutnnbtkogvnm.supabase.co/functions/v1/push-notification'::TEXT,
        body := jsonb_build_object(
            'call_id', NEW.id,
            'kingdom_id', NEW.kingdom_id,
            'title', NEW.title,
            'target_x', NEW.target_x,
            'target_y', NEW.target_y,
            'created_by', NEW.created_by,
            'arrival', NEW.arrival
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
