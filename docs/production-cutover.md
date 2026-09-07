# Kidversity production cutover

Target project: `cycidawgvxyrqmsejour`

## Required inputs

- Production web origin and all Auth redirect URLs
- Google Cloud service account with only Text-to-Speech synthesis access
- `GOOGLE_SERVICE_ACCOUNT_JSON` and optional `GOOGLE_TTS_VOICE`
- Random `REVIEWER_PROVISIONING_SECRET`
- First reviewer account email
- Sentry DSN and release name
- Approved privacy, terms, guardian-consent, and retention wording

Never place Google, Sentry, database, or Supabase secret keys in Flutter assets,
`.env`, source control, or client build arguments.

## Verification before deployment

1. Install Docker Desktop and start its Linux container engine.
2. Update the Supabase CLI, then run:
   - `supabase start`
   - `supabase db reset`
   - `supabase test db`
   - `supabase db lint --local --level error`
3. Run `deno check supabase/functions/*/index.ts`.
4. Run `flutter analyze --no-pub`, `flutter test --no-pub`, and
   `flutter build web --release --no-pub`.
5. Confirm lessons 4–30 are `ready` or `in_review`, never `approved`.

## Deployment order

1. Export a schema snapshot with `supabase db dump --linked --schema-only`.
2. Push the verified database migrations.
3. Set Edge Function secrets:
   `GOOGLE_SERVICE_ACCOUNT_JSON`, `GOOGLE_TTS_VOICE`,
   `REVIEWER_PROVISIONING_SECRET`, and the platform-provided database/Supabase
   secrets.
4. Deploy all functions under `supabase/functions`.
5. Create the reviewer as a normal Auth user, then invoke
   `provision-reviewer` once with the provisioning secret.
6. Configure production Auth site URL, allowed redirects, SMTP, password
   requirements, and email confirmation.
7. Run security and performance advisors and resolve every warning.
8. Generate and review Google audio. Publish only lessons that pass the
   database publication gate.
9. Build Flutter with the target project URL, modern publishable key,
   production environment, Sentry DSN, and release name.
10. Verify learner, teacher, reviewer, account-deletion, and health flows.

## Rollback

- Keep the pre-deploy schema dump and the previous application artifact.
- If validation fails before the client cutover, do not change the client
  configuration.
- If validation fails after client cutover, redeploy the previous client
  artifact while preserving new learner data.
- Never run destructive down migrations against production learner data.
  Correct schema issues with a forward migration.
- Rotate the publishable key only if it was exposed outside intended clients;
  rotate every affected secret immediately if a privileged credential leaks.
