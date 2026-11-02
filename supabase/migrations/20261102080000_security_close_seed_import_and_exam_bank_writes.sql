-- Emergency hardening (applied 2026-11-02).
--
-- 1. A hand-made seed importer let anyone with the public key insert SQL into
--    public.seed_import_b64 and run it as the table owner via
--    public.exec_seed_import(). Both are removed.
-- 2. Exam-bank writes are server-only. The exam-bank Edge Function uses the
--    service role; signed-in learners can no longer overwrite answer keys.
-- 3. Signed-out visitors cannot call any public function by default.

DROP FUNCTION IF EXISTS public.exec_seed_import(text);
DROP TABLE IF EXISTS public.seed_import_b64;

REVOKE EXECUTE ON FUNCTION public.exam_bank_upsert(jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.exam_bank_replace_catalog(jsonb, jsonb, jsonb) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.exam_bank_ensure_paper(text, text, integer, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_upsert(jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.exam_bank_replace_catalog(jsonb, jsonb, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.exam_bank_ensure_paper(text, text, integer, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.live_questions_for_caller(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.live_questions_for_caller(uuid) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.exam_bank_draw(text, text, integer, text, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.exam_bank_pick_paper(text, text, integer, text) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.exam_bank_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.exam_bank_draw(text, text, integer, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_pick_paper(text, text, integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.exam_bank_status() TO authenticated;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC, anon;
