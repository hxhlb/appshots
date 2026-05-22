#!/bin/bash
set -euo pipefail

R2_PUBLIC_URL="${R2_PUBLIC_URL:-${CLOUDFLARE_R2_PUBLIC_BASE_URL:-https://appshots.eyhn.in}}"
R2_PUBLIC_URL="${R2_PUBLIC_URL%/}"
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

url="${R2_PUBLIC_URL}/production/appcast.xml"
file="$TEMP_DIR/appcast.xml"

for _ in 1 2; do
  status=$(curl -sSL -w "%{http_code}" "$url" -o "$file" 2> /dev/null || true)
  if [[ "$status" == "200" ]]; then
    build=$(awk -F'[<>]' '/<sparkle:version>/{print $3; exit}' "$file")
    [[ "$build" =~ ^[0-9]+$ ]] && {
      echo "[i] latest production build: $build" >&2
      echo "$build"
      exit 0
    }
  elif [[ "$status" == "404" ]]; then
    echo "[i] no existing production appcast at $url; using 0" >&2
    echo "0"
    exit 0
  fi
  sleep 1
done

echo "[-] failed to read production appcast at $url" >&2
exit 1
