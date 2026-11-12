-- Rope Pull: stop accepting decks built on a player's device.
--
-- RUN THIS ONLY AFTER the app build that uses create_rope_pull_match and
-- rope_pull_quick_match_v2 is live (and old cached web builds have had a day
-- to refresh). Older builds call the two functions below directly and will
-- get "permission denied" once this runs.
--
-- The server-side entry points still call these functions internally; they
-- run as the function owner, so revoking the app's direct access does not
-- affect them.

REVOKE EXECUTE ON FUNCTION public.create_rope_pull_room(TEXT, JSONB, BOOLEAN, TEXT, TEXT, UUID, UUID)
  FROM PUBLIC, anon, authenticated;

REVOKE EXECUTE ON FUNCTION public.rope_pull_quick_match(TEXT, JSONB, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
