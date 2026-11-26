# ACE — Advance. Conquer. Excel.

The academic learning app, served at `kidversity.app/ace`. Separate Flutter
app with its own Supabase project (ACE, `nzcmezjhgcdhfxqbnhgv`). Plan and
status: [docs/ace/PLAN.md](../docs/ace/PLAN.md).

## Run locally

```bash
cd ace
flutter run -d chrome
```

Defaults point at the ACE staging project (`lib/config.dart`). Override with
`--dart-define=ACE_SUPABASE_URL=... --dart-define=ACE_SUPABASE_KEY=...`.

## Database

Migrations live in `supabase/migrations/` and are applied in order. All
content reads go through `ace_*` functions; answer keys live in the `private`
schema and are never readable by clients.

## Import content

```bash
python -I ace/tools/import_content.py <extracted package folder> \
  --out build/ace_import.sql --chunk-dir build/ace_import \
  --pilot-school "Oxbridge (pilot)"
```

The package's own validator runs first. The output calls
`private.ace_import_package(...)`, which upserts by stable ID, refuses changed
content that kept the same `content_version`, keeps answer keys server-only and
snapshots every version. Run the chunks in order (reference, topics, lessons)
with an admin database connection. Never commit the package or the generated
SQL: both contain answer keys.

## Deploy

`scripts/vercel-build.sh` builds ACE into `build/web/ace` with
`--base-href /ace/`; `vercel.json` rewrites `/ace/*` to the ACE app. Set
`ACE_SUPABASE_URL`, `ACE_SUPABASE_KEY` and `ACE_ENV=production` in Vercel when
going live.
