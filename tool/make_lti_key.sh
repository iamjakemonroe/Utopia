#!/usr/bin/env bash
# Makes Chip Study's LTI signing key and stores it as the LTI_PRIVATE_JWK
# secret of the study-lti function, without showing it. Run once:
#   bash tool/make_lti_key.sh
# Platforms read the public half at .../functions/v1/study-lti/jwks.
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v deno >/dev/null; then echo "Needs deno (brew install deno)."; exit 1; fi
key="$(deno eval --quiet --no-config '
const k = await crypto.subtle.generateKey(
  { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
  true, ["sign", "verify"]);
const { kty, n, e, d, p, q, dp, dq, qi } = await crypto.subtle.exportKey("jwk", k.privateKey);
const kid = "study-lti-" + new Date().toISOString().slice(0, 10);
console.log(JSON.stringify({ kty, n, e, d, p, q, dp, dq, qi, kid, alg: "RS256", use: "sig" }));
')"
tmp="$(mktemp)"; chmod 600 "$tmp"; trap 'rm -f "$tmp"' EXIT
printf "LTI_PRIVATE_JWK='%s'\n" "$key" > "$tmp"
unset key
supabase secrets set --env-file "$tmp" >/dev/null
echo "Saved LTI_PRIVATE_JWK. Check: curl -s https://atrgasakfnmixhictynh.supabase.co/functions/v1/study-lti/jwks"
