#!/usr/bin/env bash
# Pushes the auth settings in supabase/config.toml (the email sender, the
# sign-in code emails, limits) to the live project, with the Resend key
# from env/resend.env. Run from anywhere: tool/push_auth_email.sh
# `supabase config push` shows what will change and asks before it does.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f env/resend.env ]; then
  echo "Missing env/resend.env. Put RESEND_API_KEY=re_... in it first." >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. env/resend.env
set +a
case "${RESEND_API_KEY:-}" in
  re_*) ;;
  "") echo "env/resend.env has no RESEND_API_KEY yet." >&2; exit 1 ;;
  *) echo "That doesn't look like a Resend key (they start with re_)." >&2; exit 1 ;;
esac
supabase config push
