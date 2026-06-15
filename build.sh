#!/bin/bash
# Builds AppTwin.app, embedding Sparkle, and ad-hoc signs it.
# The bundle is assembled + signed in a LOCAL staging dir (not iCloud Drive,
# whose metadata xattrs break codesign), then copied to dist/ for local use.
# Optional first arg stamps the version (e.g. ./build.sh 1.2.0).
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
STAGE="${APPTWIN_STAGE:-$HOME/Library/Caches/AppTwinBuild}"
APP="$STAGE/AppTwin.app"

# Universal binary so the app runs on both Apple Silicon and Intel Macs.
ARCHS="--arch arm64 --arch x86_64"
swift build -c release $ARCHS
PRODUCTS=$(swift build -c release $ARCHS --show-bin-path)

rm -rf "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

cp "$PRODUCTS/AppTwin"     "$APP/Contents/MacOS/AppTwin"
cp "$PRODUCTS/AppTwinStub" "$APP/Contents/Resources/AppTwinStub"
cp "Resources/Info.plist"       "$APP/Contents/Info.plist"
cp "Resources/AppIcon.icns"     "$APP/Contents/Resources/AppIcon.icns"

if [ -n "$VERSION" ]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$APP/Contents/Info.plist"
  plutil -replace CFBundleVersion            -string "$VERSION" "$APP/Contents/Info.plist"
fi

# Embed Sparkle.framework (the universal slice from the SPM artifact).
SPARKLE_FW=$(find .build -path "*macos-arm64_x86_64/Sparkle.framework" -type d | head -1)
if [ -z "$SPARKLE_FW" ]; then echo "Sparkle.framework not found — run 'swift package resolve'"; exit 1; fi
cp -R "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"

# Clean any extended attributes, then ad-hoc sign inside-out:
# Sparkle's nested helpers, then the framework, then the whole app.
xattr -cr "$APP"
SP="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
codesign --force --sign - "$SP/XPCServices/Downloader.xpc"
codesign --force --sign - "$SP/XPCServices/Installer.xpc"
codesign --force --sign - "$SP/Autoupdate"
codesign --force --sign - "$SP/Updater.app"
codesign --force --sign - "$APP/Contents/Frameworks/Sparkle.framework"
codesign --force --sign - "$APP"
codesign --verify --deep --strict "$APP"

# Copy to dist/ for convenient local running/testing.
rm -rf dist; mkdir -p dist
ditto "$APP" "dist/AppTwin.app"

V=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
echo "Built $APP (v$V) — signed & verified"
echo "Copied to dist/AppTwin.app for local use"
