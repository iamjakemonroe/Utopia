#!/usr/bin/env bash
# Builds Utopia for the web, to be served at https://utopia.kaivon.app/game/,
# and puts it in the landing page (../utopia-landingpage/public/game), whose
# build copies it into the site. Then deploy the site:
#   cd ../utopia-landingpage && npm run build && npx wrangler deploy
set -euo pipefail
cd "$(dirname "$0")/.."
SITE=../utopia-landingpage
flutter build web --release --base-href /game/ \
  --dart-define-from-file=env/local.json
rm -rf "$SITE/public/game"
cp -R build/web "$SITE/public/game"
du -sh "$SITE/public/game"
