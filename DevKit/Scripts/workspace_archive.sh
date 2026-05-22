#!/bin/zsh

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)

PROJECT="Appshots.xcodeproj"
SCHEME="Appshots"
BUNDLE_ID="com.kwwk.appshots"
BUILD_DIR="$PROJECT_ROOT/.build"
ARCHIVE_PATH="$BUILD_DIR/${SCHEME}.xcarchive"
DERIVED_DATA="$BUILD_DIR/DerivedData"
XCODEBUILD_LOG="$PROJECT_ROOT/xcodebuild.log"

source "$SCRIPT_DIR/project-env.sh"
load_project_info

mkdir -p "$BUILD_DIR" "$DERIVED_DATA"

cleanup_build_artifacts() {
  echo "[*] cleaning previous archive artifacts"
  rm -rf "$ARCHIVE_PATH" "$DERIVED_DATA"
  rm -f "$XCODEBUILD_LOG"
  mkdir -p "$BUILD_DIR" "$DERIVED_DATA"
}

run_xcodebuild() {
  if command -v xcbeautify > /dev/null 2>&1; then
    xcodebuild "$@" 2>&1 | tee "$XCODEBUILD_LOG" | xcbeautify --is-ci --disable-logging --disable-colored-output
  else
    xcodebuild "$@" 2>&1 | tee "$XCODEBUILD_LOG"
  fi
}

PUBLIC_BASE_URL="${CLOUDFLARE_R2_PUBLIC_BASE_URL:-https://appshots.eyhn.in}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL%/}"
SPARKLE_FEED_URL="${SPARKLE_FEED_URL:-${PUBLIC_BASE_URL}/production/appcast.xml}"

echo "[*] archiving $SCHEME"
echo "[i] version: $MARKETING_VERSION ($PROJECT_VERSION)"
echo "[i] feed: $SPARKLE_FEED_URL"

if [[ -n "${CODE_SIGNING_IDENTITY:-}" && -n "${CODE_SIGNING_TEAM:-}" ]]; then
  echo "[*] archiving with code signing"
  echo "[i] identity: $CODE_SIGNING_IDENTITY"
  echo "[i] team: $CODE_SIGNING_TEAM"
  CODE_SIGN_ARGS=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGN_IDENTITY="$CODE_SIGNING_IDENTITY"
    DEVELOPMENT_TEAM="$CODE_SIGNING_TEAM"
  )
elif [[ "${CODE_SIGNING_ALLOWED:-}" == "NO" ]]; then
  echo "[*] archiving without code signing (explicitly disabled)"
  CODE_SIGN_ARGS=(
    CODE_SIGN_STYLE=Manual
    CODE_SIGNING_ALLOWED=NO
    CODE_SIGN_IDENTITY=""
  )
else
  echo "[*] archiving without code signing"
  CODE_SIGN_ARGS=()
fi

cleanup_build_artifacts

run_xcodebuild \
  -project "$PROJECT_ROOT/$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  -derivedDataPath "$DERIVED_DATA" \
  -skipPackagePluginValidation \
  -skipMacroValidation \
  archive \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime" \
  MARKETING_VERSION="$MARKETING_VERSION" \
  CURRENT_PROJECT_VERSION="$PROJECT_VERSION" \
  SPARKLE_FEED_URL="$SPARKLE_FEED_URL" \
  "${CODE_SIGN_ARGS[@]}"

echo "[*] archive generated at $ARCHIVE_PATH"

APP_PATH="$ARCHIVE_PATH/Products/Applications/$SCHEME.app"
if [[ -n "${CODE_SIGNING_IDENTITY:-}" ]]; then
  "$SCRIPT_DIR/sign-release-app.sh" "$APP_PATH"
fi
