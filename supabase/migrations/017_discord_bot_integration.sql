-- ============================================================
-- Migration 017: Discord Bot Integration
-- ============================================================
-- 1. Bot System User in profiles erstellen
-- 2. Trigger fuer Pledge-Aenderungen → pledge-to-discord Edge Function
-- 3. RLS Policy fuer Bot-User auf calls
-- ============================================================

-- 1. Bot System User erstellen
-- Feste UUID damit alle Environments denselben Bot-User haben
-- Muss zuerst in auth.users existieren (FK Constraint auf profiles.id)
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at)
VALUES (
    '00000000-0000-0000-0000-000000000001'::UUID,
    '00000000-0000-0000-0000-000000000000'::UUID,
    'authenticated',
    'authenticated',
    'bot@traviantimer.local',
    '',
    now(),
    now(),
    now()
)
ON CONFLICT (id) DO NOTHING;

INSERT INTO profiles (id, player_name, role)
VALUES (
    '00000000-0000-0000-0000-000000000001'::UUID,
    'Discord-Bot',
    'caller'
)
ON CONFLICT (id) DO NOTHING;

-- 2. Trigger: Pledge-Aenderungen → pledge-to-discord Edge Function
-- Wird nach INSERT/UPDATE/DELETE auf pledges aufgerufen
-- Sendet call_id und event-Typ an die Edge Function

CREATE OR REPLACE FUNCTION notify_pledge_change()
RETURNS TRIGGER AS $$
DECLARE
    request_id BIGINT;
    affected_call_id UUID;
BEGIN
    -- Bei DELETE ist NEW null, bei INSERT/UPDATE ist OLD null/vorhanden
    affected_call_id := COALESCE(NEW.call_id, OLD.call_id);

    -- Nur wenn der Call einen discord_channel_id hat
    IF EXISTS (
        SELECT 1 FROM calls
        WHERE id = affected_call_id
        AND discord_channel_id IS NOT NULL
    ) THEN
        SELECT net.http_post(
            url := 'https://pnawukicutnnbtkogvnm.supabase.co/functions/v1/pledge-to-discord'::TEXT,
            body := jsonb_build_object(
                'call_id', affected_call_id,
                'event', TG_OP,
                'player_name', COALESCE(NEW.player_name, OLD.player_name)
            ),
            headers := jsonb_build_object(
                'Content-Type', 'application/json',
                'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBuYXd1a2ljdXRubmJ0a29ndm5tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk1NTM3NjksImV4cCI6MjA1NTEyOTc2OX0.r5f0gOPR0WHkfzcTdy-_DVGe_fxVOXzZ1UyUtGiXl6Y'
            )
        ) INTO request_id;

        RAISE NOTICE '[notify_pledge_change] Request gesendet fuer Call %: %', affected_call_id, request_id;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger erstellen
DROP TRIGGER IF EXISTS on_pledge_change_discord ON pledges;
CREATE TRIGGER on_pledge_change_discord
    AFTER INSERT OR UPDATE OR DELETE ON pledges
    FOR EACH ROW
    EXECUTE FUNCTION notify_pledge_change();

-- 3. RLS Policy: Bot-User darf Calls erstellen
-- Der Bot-User braucht keine RLS-Ausnahme weil push-call die Service-Role nutzt.
-- Aber fuer Konsistenz erlauben wir dem Bot-User trotzdem Zugriff.

-- Keine zusaetzliche RLS Policy noetig:
-- - push-call Edge Function nutzt Service Role Key (bypassed RLS)
-- - pledge-to-discord Edge Function nutzt Service Role Key (bypassed RLS)
-- - Der Bot-User wird nur als created_by Referenz genutzt
