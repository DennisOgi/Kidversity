-- Lesson file uploads (teacher PPT/PDF)
INSERT INTO storage.buckets (id, name, public, file_size_limit)
VALUES ('lesson-files', 'lesson-files', false, 26214400)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Users upload own lesson files" ON storage.objects;
CREATE POLICY "Users upload own lesson files"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'lesson-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "Users read own lesson files" ON storage.objects;
CREATE POLICY "Users read own lesson files"
  ON storage.objects FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'lesson-files'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );
