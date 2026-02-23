-- ============================================================
-- Migration 032: Account-Löschung (App Store Guideline 5.1.1v)
-- ============================================================
-- SQL-Funktion die alle User-Daten aufräumt bevor der
-- Auth-User via Admin API gelöscht wird.
--
-- Ablauf:
-- 1. pledges löschen (kein ON DELETE CASCADE)
-- 2. calls.created_by auf NULL setzen (Calls bleiben erhalten)
-- 3. notifications.actor_id auf NULL setzen
-- 4. guide_session_progress.checked_by auf NULL setzen
-- 5. auth.users löschen → CASCADE löscht profiles + alle
--    abhängigen Tabellen (villages, device_tokens, troop_snapshots,
--    notifications, notification_preferences, tool_favorites,
--    guide_sessions, guide_session_members)
-- ============================================================

-- Funktion: Bereinigt User-Daten vor Account-Löschung
-- Wird von der Edge Function `delete-account` aufgerufen.
CREATE OR REPLACE FUNCTION delete_user_data(target_user_id UUID)
RETURNS VOID AS $$
BEGIN
    -- 1. Pledges löschen (FK ohne CASCADE → muss manuell)
    DELETE FROM pledges WHERE user_id = target_user_id;

    -- 2. Calls erhalten, aber created_by entkoppeln
    --    (Calls gehören dem Kingdom, nicht dem einzelnen User)
    UPDATE calls SET created_by = NULL WHERE created_by = target_user_id;

    -- 3. Notification-Actor-Referenzen entkoppeln
    UPDATE notifications SET actor_id = NULL WHERE actor_id = target_user_id;

    -- 4. Guide-Progress-Referenzen entkoppeln
    UPDATE guide_session_progress SET checked_by = NULL WHERE checked_by = target_user_id;

    -- 5. Profile löschen → CASCADE räumt alle abhängigen Tabellen auf
    --    (villages, device_tokens, troop_snapshots, notifications,
    --     notification_preferences, tool_favorites, guide_sessions,
    --     guide_session_members)
    DELETE FROM profiles WHERE id = target_user_id;

    RAISE NOTICE '[delete_user_data] User % erfolgreich bereinigt', target_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- calls.created_by muss nullable sein für die Entkopplung
ALTER TABLE calls ALTER COLUMN created_by DROP NOT NULL;
