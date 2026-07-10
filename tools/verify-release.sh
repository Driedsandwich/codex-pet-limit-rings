#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$ROOT/tmp/codex-pet-limit-rings-release-check"
PREVIEW="$ROOT/tmp/codex-pet-limit-rings-release-check.png"

mkdir -p "$ROOT/tmp"

bash -n "$ROOT"/tools/*.sh
plutil -lint "$ROOT/tools/CodexPetLimitRings-Info.plist" >/dev/null
"$ROOT/tools/test-limit-rings.sh"

swiftc \
  -parse-as-library \
  "$ROOT/tools/codex-pet-limit-rings.swift" \
  -o "$APP_BIN" \
  -framework AppKit \
  -lsqlite3

"$APP_BIN" --preview "$PREVIEW" --size 164
test -s "$PREVIEW"

if rg -n 'access_token|Authorization.*Bearer|URLSession\.shared|backend-api/wham/usage' \
  "$ROOT/tools/codex-pet-limit-rings.swift"; then
  echo "release verification failed: legacy credential path remains in app source" >&2
  exit 1
fi

if rg -n --hidden \
  --glob '!.git/**' \
  --glob '!tmp/**' \
  --glob '!docs/assets/**' \
  '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----)' \
  "$ROOT"; then
  echo "release verification failed: secret-like material found" >&2
  exit 1
fi

rg -q 'MIT License' "$ROOT/LICENSE"

plist_version="$(plutil -extract CFBundleShortVersionString raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"
source_version="$(sed -n 's/.*var version = "\([^"]*\)".*/\1/p' "$ROOT/tools/codex-pet-limit-rings.swift" | head -1)"
if [[ -z "$source_version" || "$plist_version" != "$source_version" ]]; then
  echo "release verification failed: app-server client version does not match Info.plist" >&2
  exit 1
fi

echo "release verification passed for v$plist_version"
