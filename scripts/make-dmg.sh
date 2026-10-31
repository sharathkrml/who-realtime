#!/bin/sh
# Builds both app bundles and packs them into one distributable DMG.
# The apps are ad-hoc signed, not notarized: on another Mac the first launch
# needs right-click → Open (or System Settings → Privacy & Security → Open Anyway).
set -eu

cd "$(dirname "$0")/.."
# CI sets SKIP_BUILD=1 after it has already built and signed the bundles.
[ "${SKIP_BUILD:-0}" = 1 ] || scripts/make-app.sh

STAGE="build/dmg"
DMG="build/WhoRealtime.dmg"

rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "build/WhoRealtime.app" "build/WhoRealtime Windowed.app" "$STAGE/"
ln -s /Applications "$STAGE/Applications"

hdiutil create -volname "Who Realtime" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"
echo "Built $DMG"
