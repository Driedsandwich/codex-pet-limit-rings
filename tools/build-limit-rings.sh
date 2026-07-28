#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

APP="${1:-$ROOT/tmp/CodexPetLimitRings.app}"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
RESOURCES="$APP/Contents/Resources"
PLIST="$ROOT/tools/CodexPetLimitRings-Info.plist"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"

safe_remove_app_bundle \
  "$APP" \
  "CodexPetLimitRings.app" \
  "$ROOT/tmp" \
  "$HOME/Applications"
mkdir -p "$APP/Contents/MacOS" "$RESOURCES"
cp "$PLIST" "$APP/Contents/Info.plist"
if [[ -d "$ROOT/resources" ]]; then
  cp -R "$ROOT/resources/." "$RESOURCES/"
fi
(
  cd "$ROOT"
  swiftc \
    -parse-as-library \
    -target "arm64-apple-macosx$DEPLOYMENT_TARGET" \
    -file-prefix-map "$ROOT=." \
    tools/codex-pet-limit-rings.swift \
    -o "$BIN" \
    -framework AppKit \
    -framework UserNotifications \
    -lsqlite3
)

if ! command -v codesign >/dev/null 2>&1; then
  echo "build failed: codesign is required" >&2
  exit 1
fi
codesign --force --deep --sign - "$APP" >/dev/null
codesign --verify --deep --strict "$APP"

echo "$APP"
