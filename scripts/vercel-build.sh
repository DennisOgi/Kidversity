#!/usr/bin/env bash
set -euo pipefail

echo "==> Kidversity Vercel build"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "ERROR: Set SUPABASE_URL and SUPABASE_ANON_KEY in Vercel project Environment Variables."
  exit 1
fi

# pubspec.yaml lists .env as an asset; create it from Vercel env at build time.
cat > .env <<EOF
SUPABASE_URL=${SUPABASE_URL}
SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
OPENAI_API_KEY=${OPENAI_API_KEY:-}
SENTRY_DSN=${SENTRY_DSN:-}
ENVIRONMENT=${ENVIRONMENT:-production}
API_BASE_URL=${API_BASE_URL:-https://api.kidversity.app}
API_TIMEOUT_SECONDS=${API_TIMEOUT_SECONDS:-30}
EOF

if [[ ! -d "${HOME}/flutter" ]]; then
  echo "==> Installing Flutter (stable)..."
  git clone https://github.com/flutter/flutter.git --depth 1 -b stable "${HOME}/flutter"
fi

export PATH="${HOME}/flutter/bin:${PATH}"
flutter --version
flutter config --enable-web --no-analytics
flutter pub get

echo "==> Building Flutter web release..."
flutter build web --release \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}" \
  --dart-define=ENVIRONMENT="${ENVIRONMENT:-production}" \
  --dart-define=OPENAI_API_KEY="${OPENAI_API_KEY:-}" \
  --dart-define=SENTRY_DSN="${SENTRY_DSN:-}"

echo "==> Build complete: build/web"
