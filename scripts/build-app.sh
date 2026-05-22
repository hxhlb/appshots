#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG="${1:-debug}"
VERSION_XCCONFIG="$ROOT_DIR/Sources/Appshots/Configuration/Version.xcconfig"
MARKETING_VERSION="$(grep '^MARKETING_VERSION' "$VERSION_XCCONFIG" | sed 's/.*= *//' | tr -d '[:space:]')"
CURRENT_PROJECT_VERSION="$(grep '^CURRENT_PROJECT_VERSION' "$VERSION_XCCONFIG" | sed 's/.*= *//' | tr -d '[:space:]')"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-https://appshots.eyhn.in/production/appcast.xml}"

swift build --package-path "$ROOT_DIR" -c "$CONFIG" --product Appshots
BIN_DIR="$(swift build --package-path "$ROOT_DIR" -c "$CONFIG" --product Appshots --show-bin-path)"

APP_DIR="$ROOT_DIR/.build/Appshots.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$BIN_DIR/Appshots" "$MACOS_DIR/Appshots"
cp "$ROOT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ -d "$BIN_DIR/kwwk-computer-use-core_KWWKComputerUseCore.bundle" ]]; then
    cp -R "$BIN_DIR/kwwk-computer-use-core_KWWKComputerUseCore.bundle" "$RESOURCES_DIR/"
fi
if [[ -f "$ROOT_DIR/Resources/AppIcon.icns" ]]; then
    cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
fi
SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d -print -quit 2>/dev/null || true)"
if [[ -n "$SPARKLE_FRAMEWORK" ]]; then
    cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"
fi
chmod +x "$MACOS_DIR/Appshots"

/usr/libexec/PlistBuddy -c "Set :CFBundleExecutable Appshots" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.kwwk.appshots" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleName Appshots" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $MARKETING_VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $CURRENT_PROJECT_VERSION" "$CONTENTS_DIR/Info.plist"
/usr/libexec/PlistBuddy -c "Set :SUFeedURL $SPARKLE_FEED_URL" "$CONTENTS_DIR/Info.plist"

echo "$APP_DIR"
