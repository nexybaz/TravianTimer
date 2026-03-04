-- 034: Avatar Storage Bucket
-- Erstellt einen Storage Bucket fuer Profilbilder.
-- Pfad-Schema: {userId}/avatar.jpg
-- Public Bucket (jeder kann lesen), Schreib-/Loeschzugriff nur auf eigenen Ordner.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars',
    'avatars',
    true,
    1048576,  -- 1 MB
    ARRAY['image/jpeg', 'image/png']
)
ON CONFLICT (id) DO NOTHING;

-- Jeder kann Avatare lesen (public bucket)
CREATE POLICY "Avatare sind öffentlich lesbar"
ON storage.objects FOR SELECT
USING (bucket_id = 'avatars');

-- User darf nur in eigenen Ordner hochladen ({userId}/...)
CREATE POLICY "User kann eigenen Avatar hochladen"
ON storage.objects FOR INSERT
WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- User darf eigenen Avatar ueberschreiben
CREATE POLICY "User kann eigenen Avatar aktualisieren"
ON storage.objects FOR UPDATE
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- User darf eigenen Avatar loeschen
CREATE POLICY "User kann eigenen Avatar löschen"
ON storage.objects FOR DELETE
USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
);
