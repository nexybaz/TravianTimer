-- ============================================================
-- Migration 031: Push + In-App Notification bei Guide-Session Fortschritt
-- ============================================================
-- Wenn ein Spieler in einer Session einen Schritt abhakt,
-- erhalten alle anderen Session-Mitglieder eine Benachrichtigung.
-- ============================================================

-- 1. Neue Preference-Spalte
ALTER TABLE notification_preferences
    ADD COLUMN guide_progress BOOLEAN DEFAULT true;

-- ============================================================
-- 2. In-App Notification Trigger
-- ============================================================

CREATE OR REPLACE FUNCTION create_guide_progress_notification()
RETURNS TRIGGER AS $$
DECLARE
    member RECORD;
    checker_name TEXT;
BEGIN
    -- Name des Abhakers laden
    SELECT player_name INTO checker_name
    FROM profiles
    WHERE id = NEW.checked_by;

    -- Fuer jedes Session-Mitglied (ausser Abhaker) mit Preference
    FOR member IN
        SELECT gsm.user_id
        FROM guide_session_members gsm
        LEFT JOIN notification_preferences np ON np.user_id = gsm.user_id
        WHERE gsm.session_id = NEW.session_id
          AND gsm.user_id != NEW.checked_by
          AND (np.guide_progress IS NULL OR np.guide_progress = true)
    LOOP
        INSERT INTO notifications (user_id, type, title, body, reference_id, reference_type, actor_id, actor_name)
        VALUES (
            member.user_id,
            'guide_progress',
            'Schnellsiedelguide',
            COALESCE(checker_name, 'Ein Spieler') || ' hat Fortschritte eingetragen!',
            NEW.session_id,
            'guide_session',
            NEW.checked_by,
            COALESCE(checker_name, 'Unbekannt')
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_guide_progress_notification
    AFTER INSERT ON guide_session_progress
    FOR EACH ROW
    EXECUTE FUNCTION create_guide_progress_notification();

-- ============================================================
-- 3. Push Notification Trigger (via Edge Function)
-- ============================================================

CREATE OR REPLACE FUNCTION notify_guide_progress()
RETURNS TRIGGER AS $$
DECLARE
    request_id BIGINT;
BEGIN
    SELECT net.http_post(
        url := 'https://pnawukicutnnbtkogvnm.supabase.co/functions/v1/push-notification'::TEXT,
        body := jsonb_build_object(
            'type', 'guide_progress',
            'session_id', NEW.session_id,
            'step_id', NEW.step_id,
            'checked_by', NEW.checked_by
        ),
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBuYXd1a2ljdXRubmJ0a29ndm5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk1NTM3NjksImV4cCI6MjA1NTEyOTc2OX0.r5f0gOPR0WHkfzcTdy-_DVGe_fxVOXzZ1UyUtGiXl6Y'
        )
    ) INTO request_id;

    RAISE NOTICE '[notify_guide_progress] Push request gesendet: %', request_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_guide_progress_push
    AFTER INSERT ON guide_session_progress
    FOR EACH ROW
    EXECUTE FUNCTION notify_guide_progress();
