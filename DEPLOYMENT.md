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
| `SUPABASE_URL` | Yes | Supabase project URL |
| `SUPABASE_ANON_KEY` | Yes | Supabase **anon/public** key (not service_role) |
| `ENVIRONMENT` | No | Use `production` |
| `OPENAI_API_KEY` | No | Enables AI lesson generation |
| `SENTRY_DSN` | No | Error tracking |

Apply to **Production**, **Preview**, and **Development** if you use preview deployments.

## 3. Supabase auth redirect URLs

In Supabase → **Authentication → URL Configuration**, add your Vercel URLs:

- Site URL: `https://your-project.vercel.app`
- Redirect URLs: `https://your-project.vercel.app/**`

## 4. Deploy

Push to `main` on GitHub. Vercel redeploys automatically on each push.

## Local production build (optional)

```bash
export SUPABASE_URL=https://xxx.supabase.co
export SUPABASE_ANON_KEY=eyJ...
bash scripts/vercel-build.sh
# Serve build/web with any static server
```
