#!/usr/bin/env bash
# Sends the Flutterwave keys in env/flutterwave.env to the live project's
# secrets, for the web-pay and web-pay-hook functions:
#   FLW_SECRET_KEY=FLWSECK-...        (Settings > API keys; FLWSECK_TEST-... for tests)
#   FLW_WEBHOOK_HASH=any-long-secret  (the same as Settings > Webhooks > Secret hash)
# Run from anywhere: tool/push_payment_keys.sh
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f env/flutterwave.env ]; then
  echo "Missing env/flutterwave.env. Put FLW_SECRET_KEY and FLW_WEBHOOK_HASH in it first." >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. env/flutterwave.env
set +a
case "${FLW_SECRET_KEY:-}" in
  FLWSECK*) ;;
  *) echo "FLW_SECRET_KEY should start with FLWSECK." >&2; exit 1 ;;
esac
if [ "${#FLW_WEBHOOK_HASH}" -lt 16 ]; then
  echo "FLW_WEBHOOK_HASH should be a long random secret (16+ characters)." >&2
  exit 1
fi
supabase secrets set FLW_SECRET_KEY="$FLW_SECRET_KEY" FLW_WEBHOOK_HASH="$FLW_WEBHOOK_HASH"
echo "Done. Webhook URL for Flutterwave: https://atrgasakfnmixhictynh.supabase.co/functions/v1/web-pay-hook"
