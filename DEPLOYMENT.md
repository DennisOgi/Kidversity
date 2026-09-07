# Deploy Kidversity to Vercel (GitHub)

Kidversity is a **Flutter web** app. Vercel builds it with `scripts/vercel-build.sh` and serves static files from `build/web`.

## 1. Connect GitHub to Vercel

1. Open [vercel.com/new](https://vercel.com/new)
2. Import **DennisOgi/Kidversity**
3. Leave **Framework Preset** as *Other* (or let Vercel read `vercel.json`)
4. Confirm:
   - **Build Command:** `bash scripts/vercel-build.sh` (from `vercel.json`)
   - **Output Directory:** `build/web`

## 2. Environment variables (required)

In Vercel → Project → **Settings → Environment Variables**, add:

| Variable | Required | Notes |
|----------|----------|--------|
| `SUPABASE_URL` | Yes | `https://cycidawgvxyrqmsejour.supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Yes | Dashboard → API → publishable key |
| `SUPABASE_ANON_KEY` | Yes until rebuild | Legacy anon JWT; keep in sync with the new project |
| `ENVIRONMENT` | No | Use `production` |
| `SENTRY_DSN` | No | Error tracking |

Apply to **Production**, **Preview**, and **Development** if you use preview deployments.

## 3. Supabase auth redirect URLs

In Supabase → **Authentication → URL Configuration**, add your Vercel URLs:

- Site URL: `https://your-project.vercel.app`
- Redirect URLs: `https://your-project.vercel.app/**`

## 4. Deploy

Push to `main` on GitHub. Vercel production deploys **only** from `main`.
Feature-branch pushes create preview URLs; they do not update
https://kidversity.vercel.app.

Point Vercel `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` (or
`SUPABASE_ANON_KEY`) at project `cycidawgvxyrqmsejour` before the Mandarin
Foundation build goes live. The previous project will not serve this schema.

## Local production build (optional)

```bash
export SUPABASE_URL=https://xxx.supabase.co
export SUPABASE_ANON_KEY=eyJ...
bash scripts/vercel-build.sh
# Serve build/web with any static server
```
