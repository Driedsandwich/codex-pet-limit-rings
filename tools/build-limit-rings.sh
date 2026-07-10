#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-$ROOT/tmp/CodexPetLimitRings.app}"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
PLIST="$ROOT/tools/CodexPetLimitRings-Info.plist"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$PLIST" "$APP/Contents/Info.plist"
swiftc \
  -parse-as-library \
  -target "arm64-apple-macosx$DEPLOYMENT_TARGET" \
  "$ROOT/tools/codex-pet-limit-rings.swift" \
  -o "$BIN" \
  -framework AppKit \
  -lsqlite3

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
fi

echo "$APP"
