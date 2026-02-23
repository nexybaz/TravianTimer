-- ============================================================
-- 006_fix_handle_new_user.sql
-- Fix: search_path + raw_user_meta_data Feld-Name
-- ============================================================

-- Die Funktion braucht SET search_path = public damit sie
-- die profiles-Tabelle findet, auch als SECURITY DEFINER.
-- Ausserdem: Supabase auth.users nutzt raw_user_meta_data (mit 'a').

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (id, player_name)
    VALUES (
        NEW.id,
        COALESCE(
            NEW.raw_user_meta_data->>'player_name',
            'Spieler'
        )
    );
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Fehler loggen aber User-Erstellung nicht blockieren
        RAISE WARNING 'handle_new_user fehlgeschlagen: % %', SQLERRM, SQLSTATE;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;
