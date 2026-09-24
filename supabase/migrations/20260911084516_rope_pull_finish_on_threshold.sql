-- End the match as soon as a team pulls the knot all the way across.
CREATE OR REPLACE FUNCTION private.rope_pull_finish_on_threshold()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, private
AS $$
BEGIN
  IF NEW.status = 'playing' AND abs(NEW.rope_score) >= 10 THEN
    NEW.status := 'finished';
    NEW.updated_at := now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS rope_pull_finish_on_threshold ON public.rope_pull_rooms;
CREATE TRIGGER rope_pull_finish_on_threshold
  BEFORE UPDATE ON public.rope_pull_rooms
  FOR EACH ROW
  EXECUTE FUNCTION private.rope_pull_finish_on_threshold();
