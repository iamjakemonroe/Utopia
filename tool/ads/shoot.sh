#!/bin/zsh
# Films the shots the ads are cut from: the perf harness (tool/perf) at a
# phone's size drawn at full 1080x1920, each scene for a few seconds, into
# build/ads/raw/<shot>. Needs Playwright (see tool/perf/measure.mjs).
set -eu
cd "${0:A:h}/../.."
flutter build web --profile --wasm --no-strip-wasm --no-web-resources-cdn \
  -t tool/perf/perf_main.dart --dart-define-from-file=env/local.json -o build/perf
R=build/ads/raw
shot() {
  rm -rf "$R/$1"
  node tool/ads/record.mjs build/perf "$R/$1" "$2&scale=2.6667" "$3" 1080x1920@1 "${4:-6}" |
    sed "s/^/$1: /"
}
shot ludomid "scene=ludomid&world=utopia" 60
shot eights "scene=eights&world=utopia" 32
shot chip_doodle "scene=chipshow&world=utopia_doodle" 16
shot chip_halloween "scene=chipshow&world=utopia_halloween" 16
shot chipdraws "scene=chipdraws&world=utopia_doodle" 16 1.2
for w in utopia_doodle utopia_halloween utopia_winter utopia_music utopia_heaven utopia_hell \
  utopia_dojo utopia_deep utopia_alien utopia_birthday utopia_zombie utopia; do
  shot "cards_$w" "scene=cards&world=$w" 5
done
shot home_utopia "scene=home&world=utopia" 8
shot home_winter "scene=home&world=utopia_winter" 8
