-- ============================================================
-- Migration 026: Notification Center
-- ============================================================
-- In-App-Benachrichtigungsfeed + konfigurierbare Push-Einstellungen.
-- Fan-Out-Modell: 1 Zeile pro Empfaenger pro Event.
-- ============================================================

-- ============================================================
-- 1. notifications-Tabelle
-- ============================================================

CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    kingdom_id      INT,
    type            TEXT NOT NULL,           -- 'new_call' | 'pledge_received'
    title           TEXT NOT NULL,
    body            TEXT NOT NULL,
    reference_id    UUID,                    -- FK zu calls.id (Deep Link)
    reference_type  TEXT DEFAULT 'call',     -- 'call' | erweiterbar
    actor_id        UUID REFERENCES profiles(id),
    actor_name      TEXT,                    -- denormalized player_name
    is_read         BOOLEAN DEFAULT false,
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_notifications_user_id ON notifications(user_id);
CREATE INDEX idx_notifications_user_unread ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX idx_notifications_created ON notifications(user_id, created_at DESC);

-- RLS
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Benachrichtigungen lesen"
    ON notifications FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Benachrichtigungen aktualisieren"
    ON notifications FOR UPDATE
    USING (user_id = auth.uid());

-- Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- ============================================================
-- 2. notification_preferences-Tabelle
-- ============================================================

CREATE TABLE notification_preferences (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE UNIQUE,
    new_call            BOOLEAN DEFAULT true,
    pledge_received     BOOLEAN DEFAULT true,
    updated_at      TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Einstellungen lesen"
    ON notification_preferences FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Einstellungen aktualisieren"
    ON notification_preferences FOR UPDATE
    USING (user_id = auth.uid());

CREATE POLICY "Eigene Einstellungen erstellen"
    ON notification_preferences FOR INSERT
    WITH CHECK (user_id = auth.uid());

-- ============================================================
-- 3. Auto-Create Preferences bei neuem Profil
-- ============================================================

CREATE OR REPLACE FUNCTION create_notification_preferences()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO notification_preferences (user_id)
    VALUES (NEW.id)
    ON CONFLICT (user_id) DO NOTHING;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_profile_created_prefs
    AFTER INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION create_notification_preferences();

-- Bestehende Profile: Preferences nachholen
INSERT INTO notification_preferences (user_id)
SELECT id FROM profiles
ON CONFLICT (user_id) DO NOTHING;

-- ============================================================
-- 4. Trigger: Notifications bei neuem Call
-- ============================================================

CREATE OR REPLACE FUNCTION create_call_notifications()
RETURNS TRIGGER AS $$
DECLARE
    member RECORD;
    creator_name TEXT;
BEGIN
    -- Creator-Name laden
    SELECT player_name INTO creator_name
    FROM profiles
    WHERE id = NEW.created_by;

    -- Fuer jedes Kingdom-Mitglied (ausser Ersteller) mit Preference
    FOR member IN
        SELECT p.id
        FROM profiles p
        LEFT JOIN notification_preferences np ON np.user_id = p.id
        WHERE p.kingdom_id = NEW.kingdom_id
          AND p.id != NEW.created_by
          AND (np.new_call IS NULL OR np.new_call = true)
    LOOP
        INSERT INTO notifications (user_id, kingdom_id, type, title, body, reference_id, reference_type, actor_id, actor_name)
        VALUES (
            member.id,
            NEW.kingdom_id,
            'new_call',
            'Neuer Deff-Call',
            COALESCE(NEW.title, 'Deff-Call') || ' (' || COALESCE(NEW.target_x::TEXT, '?') || '|' || COALESCE(NEW.target_y::TEXT, '?') || ')',
            NEW.id,
            'call',
            NEW.created_by,
            COALESCE(creator_name, 'Unbekannt')
        );
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_call_notifications
    AFTER INSERT ON calls
    FOR EACH ROW
    EXECUTE FUNCTION create_call_notifications();

-- ============================================================
-- 5. Trigger: Notification bei neuem Pledge
-- ============================================================

CREATE OR REPLACE FUNCTION create_pledge_notification()
RETURNS TRIGGER AS $$
DECLARE
    call_owner UUID;
    call_title TEXT;
    call_kingdom_id INT;
BEGIN
    -- Call-Ersteller und Titel laden
    SELECT created_by, title, kingdom_id
    INTO call_owner, call_title, call_kingdom_id
    FROM calls
    WHERE id = NEW.call_id;

    -- Nicht sich selbst benachrichtigen
    IF call_owner IS NULL OR call_owner = NEW.user_id THEN
        RETURN NEW;
    END IF;

    -- Nur wenn Empfaenger pledge_received aktiviert hat
    IF EXISTS (
        SELECT 1 FROM notification_preferences
        WHERE user_id = call_owner AND pledge_received = false
    ) THEN
        RETURN NEW;
    END IF;

    INSERT INTO notifications (user_id, kingdom_id, type, title, body, reference_id, reference_type, actor_id, actor_name)
    VALUES (
        call_owner,
        call_kingdom_id,
        'pledge_received',
        'Truppen zugesagt',
        COALESCE(NEW.player_name, 'Jemand') || ' hat Truppen fuer "' || COALESCE(call_title, 'Deff-Call') || '" zugesagt',
        NEW.call_id,
        'call',
        NEW.user_id,
        COALESCE(NEW.player_name, 'Unbekannt')
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_pledge_notification
    AFTER INSERT ON pledges
    FOR EACH ROW
    EXECUTE FUNCTION create_pledge_notification();
