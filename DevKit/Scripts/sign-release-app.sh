#!/bin/zsh

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <path-to-app>"
  exit 1
fi

APP_PATH="$1"

if [[ ! -d "$APP_PATH" ]]; then
  echo "[-] app path does not exist: $APP_PATH"
  exit 1
fi

if [[ -z "${CODE_SIGNING_IDENTITY:-}" ]]; then
  echo "[-] CODE_SIGNING_IDENTITY is not set"
  exit 1
fi

echo "[*] signing release app with hardened runtime"
echo "[i] app: $APP_PATH"
echo "[i] identity: $CODE_SIGNING_IDENTITY"

sign_path() {
  local path="$1"
  shift

  if [[ ! -e "$path" ]]; then
    echo "[i] skipping missing signing path: $path"
    return 0
  fi

  echo "[*] signing: $path"
  /usr/bin/codesign --force --sign "$CODE_SIGNING_IDENTITY" \
    --timestamp \
    --options runtime \
    "$@" \
    "$path"
}

SPARKLE_PATH="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_PATH" ]]; then
  sign_path "$SPARKLE_PATH/Versions/B/XPCServices/Installer.xpc"
  sign_path "$SPARKLE_PATH/Versions/B/XPCServices/Downloader.xpc" --preserve-metadata=entitlements
  sign_path "$SPARKLE_PATH/Versions/B/Autoupdate"
  sign_path "$SPARKLE_PATH/Versions/B/Updater.app"
  sign_path "$SPARKLE_PATH"
  /usr/bin/codesign --verify --deep --strict --verbose=2 "$SPARKLE_PATH"
fi

/usr/bin/codesign --force --deep --sign "$CODE_SIGNING_IDENTITY" \
  --timestamp \
  --options runtime \
  --preserve-metadata=identifier,entitlements \
  "$APP_PATH"

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "[+] release app signed successfully"
