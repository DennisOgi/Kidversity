#!/usr/bin/env bash
set -euo pipefail

echo "==> Kidversity Vercel build"

SUPABASE_CLIENT_KEY="${SUPABASE_PUBLISHABLE_KEY:-${SUPABASE_ANON_KEY:-}}"
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_CLIENT_KEY}" ]]; then
  echo "ERROR: Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY) in Vercel."
  exit 1
fi

# pubspec.yaml lists .env as an asset; create it from Vercel env at build time.
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_PUBLISHABLE_KEY=${SUPABASE_CLIENT_KEY}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY:-${SUPABASE_CLIENT_KEY}}
SENTRY_DSN=${SENTRY_DSN:-}
ENVIRONMENT=${ENVIRONMENT:-production}
APP_RELEASE=${APP_RELEASE:-${VERCEL_GIT_COMMIT_SHA:-production}}
API_BASE_URL=${API_BASE_URL:-https://api.kidversity.app}
API_TIMEOUT_SECONDS=${API_TIMEOUT_SECONDS:-30}
EOF

# Past questions are fetched by the exam-bank Edge Function. Never pass the
# SdashAPI token to the web build: everything in the build is public.
if [[ -n "${SDASH_ACCESS_TOKEN:-}" ]]; then
  echo "WARNING: SDASH_ACCESS_TOKEN is set in Vercel. Remove it; it belongs in Supabase function secrets only."
fi

if [[ ! -d "${HOME}/flutter" ]]; then
  echo "==> Installing Flutter (stable)..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${HOME}/flutter"
fi

export PATH="${HOME}/flutter/bin:${PATH}"
flutter --version
flutter config --enable-web --no-analytics
flutter pub get

echo "==> Building Flutter web release (PWA offline-first)..."
flutter build web --release \
  --pwa-strategy=offline-first \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_PUBLISHABLE_KEY="${SUPABASE_CLIENT_KEY}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-${SUPABASE_CLIENT_KEY}}" \
  --dart-define=ENVIRONMENT="${ENVIRONMENT:-production}" \
  --dart-define=APP_RELEASE="${APP_RELEASE:-${VERCEL_GIT_COMMIT_SHA:-production}}" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"

echo "==> Build complete: build/web"

# ACE (Advance. Conquer. Excel.) lives at /ace as its own Flutter app with
# its own Supabase project. Built after Kidversity because that build
# replaces build/web. Set ACE_SUPABASE_URL / ACE_SUPABASE_KEY in Vercel to
# override the staging defaults in ace/lib/config.dart.
echo "==> Building ACE into build/web/ace..."
(
  cd ace
  flutter pub get
  flutter build web --release \
    --base-href /ace/ \
    --pwa-strategy=none \
    -o ../build/web/ace \
    ${ACE_SUPABASE_URL:+--dart-define=ACE_SUPABASE_URL="${ACE_SUPABASE_URL}"} \
    ${ACE_SUPABASE_KEY:+--dart-define=ACE_SUPABASE_KEY="${ACE_SUPABASE_KEY}"} \
    --dart-define=ACE_ENV="${ACE_ENV:-staging}"
)
echo "==> ACE build complete: build/web/ace"
