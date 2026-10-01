# Sets Google Cloud TTS secrets on the Kidversity Supabase project and deploys
# the generate-mandarin-tts edge function.
#
# Prerequisites:
#   1. Google Cloud project with billing + Cloud Text-to-Speech API enabled
#   2. Service account JSON key downloaded (keep it outside git)
#   3. Supabase CLI logged in: supabase login
#
# Usage:
#   .\tool\setup_google_tts.ps1 -KeyPath "C:\secrets\kidversity-tts.json"
#   .\tool\setup_google_tts.ps1 -KeyPath "C:\secrets\kidversity-tts.json" -ProjectRef cycidawgvxyrqmsejour

param(
  [Parameter(Mandatory = $true)]
  [string]$KeyPath,

  [string]$ProjectRef = "cycidawgvxyrqmsejour",

  [string]$Voice = "cmn-CN-Standard-A",

  [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $KeyPath)) {
  throw "Service account JSON not found: $KeyPath"
}

$raw = Get-Content -LiteralPath $KeyPath -Raw -Encoding UTF8
$account = $raw | ConvertFrom-Json
if (-not $account.client_email -or -not $account.private_key) {
  throw "JSON must include client_email and private_key (Google service account key)."
}

Write-Host "Service account: $($account.client_email)"
Write-Host "Project ref:     $ProjectRef"
Write-Host "TTS voice:       $Voice"
Write-Host ""

# Compact JSON to a single line so the secret stores cleanly.
$compact = ($account | ConvertTo-Json -Compress -Depth 20)

Write-Host "Setting Edge Function secrets..."
supabase secrets set `
  "GOOGLE_SERVICE_ACCOUNT_JSON=$compact" `
  "GOOGLE_TTS_VOICE=$Voice" `
  --project-ref $ProjectRef
if ($LASTEXITCODE -ne 0) {
  throw @"
Failed to set secrets (exit $LASTEXITCODE).
Your CLI login may lack Owner/Admin on this project.
Set them in the Dashboard instead:
  https://supabase.com/dashboard/project/$ProjectRef/functions/secrets
  GOOGLE_SERVICE_ACCOUNT_JSON = (paste the full service-account JSON)
  GOOGLE_TTS_VOICE = $Voice
"@
}

if (-not $SkipDeploy) {
  Write-Host ""
  Write-Host "Deploying generate-mandarin-tts..."
  supabase functions deploy generate-mandarin-tts --project-ref $ProjectRef
  if ($LASTEXITCODE -ne 0) {
    throw "Function deploy failed (exit $LASTEXITCODE)."
  }
}

Write-Host ""
Write-Host "Done. Next steps:"
Write-Host "  1. Sign in as a reviewer (active row in reviewer_accounts)."
Write-Host "  2. Open Mandarin review in the app."
Write-Host "  3. Approve vocab/dialogue text, then tap Generate audio."
Write-Host "  4. Spot-check and approve the clip."
Write-Host "  5. Learner Listen should play the stored MP3 from mandarin-audio."
Write-Host ""
Write-Host "Keep the JSON key private. Do not commit it or add it to Flutter/.env."
