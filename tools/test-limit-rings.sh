#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_BIN="$ROOT/tmp/test-limit-rings"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"

mkdir -p "$ROOT/tmp"
swiftc \
  -D LIMIT_RINGS_TESTING \
  -target "arm64-apple-macosx$DEPLOYMENT_TARGET" \
  "$ROOT/tools/codex-pet-limit-rings.swift" \
  "$ROOT/tools/test-limit-rings.swift" \
  -o "$TEST_BIN" \
  -framework AppKit \
  -framework UserNotifications \
  -lsqlite3

"$TEST_BIN"
