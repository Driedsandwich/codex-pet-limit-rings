#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/tmp/CodexPetLimitRings.app}"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
RESOURCES="$APP/Contents/Resources"
PLIST="$ROOT/tools/CodexPetLimitRings-Info.plist"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"

rm -rf "$APP"
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

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "$APP"
