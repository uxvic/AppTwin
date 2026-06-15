#!/bin/bash
# release.sh <version> [--dry-run]
#
# Builds AppTwin, packages a DMG (for humans) + a zip (for Sparkle auto-update),
# signs the update and (re)generates appcast.xml, then publishes a GitHub release
# and pushes the updated appcast. With --dry-run it builds the artifacts and the
# appcast locally but does NOT touch GitHub or git.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
DRY_RUN="${2:-}"
if [ -z "$VERSION" ]; then
  echo "usage: ./release.sh <version> [--dry-run]   e.g. ./release.sh 1.0.0"
  exit 1
fi

REPO="uxvic/AppTwin"
STAGE="${APPTWIN_STAGE:-$HOME/Library/Caches/AppTwinBuild}"
APP="$STAGE/AppTwin.app"
TOOLS="$(find .build -path '*sparkle/Sparkle/bin' -type d | head -1)"
OUT="$STAGE/release"
FEED="$OUT/feed"                       # only the Sparkle zip lives here
DMG="$OUT/AppTwin-$VERSION.dmg"
ZIP="$FEED/AppTwin-$VERSION.zip"
DL_PREFIX="https://github.com/$REPO/releases/download/v$VERSION/"

# 1. Build + sign (clean staging dir).
./build.sh "$VERSION"

# 2. Package.
rm -rf "$OUT"; mkdir -p "$FEED"

#    DMG for first-time human download.
create-dmg \
  --volname "AppTwin $VERSION" \
  --window-size 540 380 \
  --icon-size 110 \
  --icon "AppTwin.app" 150 190 \
  --app-drop-link 390 190 \
  "$DMG" "$APP" || true   # create-dmg exits non-zero on cosmetic AppleScript warnings

#    Zip for Sparkle (ditto preserves the code signature + symlinks).
ditto -c -k --keepParent "$APP" "$ZIP"

# 3. Sign + (re)generate the appcast. generate_appcast uses the EdDSA private
#    key in the login Keychain and points enclosure URLs at the GitHub release.
"$TOOLS/generate_appcast" "$FEED" \
  --download-url-prefix "$DL_PREFIX" \
  -o appcast.xml
echo "Generated appcast.xml:"; grep -E 'sparkle:version|enclosure url' appcast.xml | sed 's/^/    /'

if [ "$DRY_RUN" = "--dry-run" ]; then
  echo
  echo "DRY RUN complete. Artifacts in $OUT"
  echo "  DMG: $DMG"
  echo "  ZIP: $ZIP"
  echo "Nothing published to GitHub."
  exit 0
fi

# 4. Publish to GitHub Releases.
gh release create "v$VERSION" "$DMG" "$ZIP" \
  --repo "$REPO" \
  --title "AppTwin $VERSION" \
  --notes "AppTwin $VERSION — run any Mac app twice with separate accounts."

# 5. Commit + push the appcast so the feed URL serves the new version.
git add appcast.xml
git commit -m "Release $VERSION"
git push

echo "✅ Released v$VERSION — users on older versions will be offered the update."
