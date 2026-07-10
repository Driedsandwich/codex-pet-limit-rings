#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_BIN="$ROOT/tmp/test-limit-rings"

mkdir -p "$ROOT/tmp"
swiftc \
  -D LIMIT_RINGS_TESTING \
  "$ROOT/tools/codex-pet-limit-rings.swift" \
  "$ROOT/tools/test-limit-rings.swift" \
  -o "$TEST_BIN" \
  -framework AppKit \
  -lsqlite3

"$TEST_BIN"
