#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

ARCHIVE_PATH="$PROJECT_ROOT/.build/Appshots.xcarchive"
APP_PATH="$ARCHIVE_PATH/Products/Applications/Appshots.app"
ARTIFACT_DIR="$PROJECT_ROOT/artifacts"
DMG_SOURCE="$PROJECT_ROOT/.build/Appshots.dmg"
ARTIFACT_PATH="$ARTIFACT_DIR/Appshots.dmg"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH" >&2
  exit 1
fi

mkdir -p "$ARTIFACT_DIR"

if [[ -f "$DMG_SOURCE" ]]; then
  echo "[*] Using existing notarized DMG from $DMG_SOURCE"
  cp "$DMG_SOURCE" "$ARTIFACT_PATH"
else
  echo "[*] Creating styled DMG from app..."
  "$SCRIPT_DIR/create-styled-dmg.sh" "$APP_PATH" "$ARTIFACT_PATH"
fi

echo "[*] Packaged DMG to $ARTIFACT_PATH"
