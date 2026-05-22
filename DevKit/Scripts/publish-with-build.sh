#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"

source ./shell-utils.sh
ensure_path
source ./project-env.sh

echo "=========================================="
echo "Publishing: Appshots production"
echo "=========================================="

step_validate() {
  echo "[*] validating environment..."
  load_project_info || exit 1

  export KEYCHAIN_DB
  KEYCHAIN_DB=$(realpath ../Keychain/Developer-ID-Keychain.keychain)
  [[ -f "$KEYCHAIN_DB" ]] || {
    echo "[-] keychain not found: $KEYCHAIN_DB"
    exit 1
  }

  export KEYCHAIN_PASSWORD="${KEYCHAIN_PASSWORD:-}"
  [[ -n "$KEYCHAIN_PASSWORD" ]] || {
    echo "[-] KEYCHAIN_PASSWORD not set"
    exit 1
  }

  source ./publish-config.sh
}

step_increment_build() {
  ./auto-increment-build.sh
}

step_archive() {
  echo "[*] archiving..."
  export CODE_SIGNING_IDENTITY CODE_SIGNING_TEAM
  ./workspace_archive.sh
}

step_notarize() {
  ARCHIVE_ROOT=$(realpath ../../.build/Appshots.xcarchive)
  APP_PATH=$(find "$ARCHIVE_ROOT" -name "*.app" -type d | head -n 1)
  [[ -n "$APP_PATH" ]] || {
    echo "[-] .app not found in archive"
    exit 1
  }

  echo "[*] notarizing..."
  export NOTARIZE_KEYCHAIN_PROFILE
  export NOTARIZE_DMG_OUTPUT="$ARCHIVE_ROOT/../Appshots.dmg"
  ./publish-submit-notary.sh "$APP_PATH"

  DMG_PATH="$ARCHIVE_ROOT/../Appshots.dmg"
  [[ -f "$DMG_PATH" ]] || {
    echo "[-] DMG not found"
    exit 1
  }
  xcrun stapler validate "$DMG_PATH" > /dev/null 2>&1 || {
    echo "[-] notarization validation failed"
    exit 1
  }
}

step_upload() {
  if [[ "${APPSHOTS_SKIP_R2_UPLOAD:-0}" == "1" ]]; then
    echo "[*] skipping R2 upload"
    return 0
  fi

  echo "[*] uploading to R2..."
  ./publish-submit-r2.sh "$DMG_PATH"
}

step_package_artifact() {
  ./common_package.sh
}

main() {
  step_validate
  step_increment_build
  step_archive
  step_notarize
  step_package_artifact
  step_upload
  echo "[+] done"
}

main "$@"
