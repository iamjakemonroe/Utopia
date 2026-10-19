#!/usr/bin/env bash
# Compiles the house players' brain (the app's own chess and checkers
# engines) to JavaScript for the house-move Edge Function. Run after
# changing the engines or the brain, then deploy house-move.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=supabase/functions/house-move/brain.js
dart compile js -O4 lib/web_workers/house_brain_js.dart -o "$OUT"
rm -f "$OUT.deps" "$OUT.map"
echo "Built $OUT ($(wc -c < "$OUT") bytes)"
