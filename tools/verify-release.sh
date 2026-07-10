#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$ROOT/tmp/codex-pet-limit-rings-release-check"
PREVIEW="$ROOT/tmp/codex-pet-limit-rings-release-check.png"
PLIST="$ROOT/tools/CodexPetLimitRings-Info.plist"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"

mkdir -p "$ROOT/tmp"

bash -n "$ROOT"/tools/*.sh
plutil -lint "$PLIST" >/dev/null
plutil -lint "$ROOT/resources/en.lproj/Localizable.strings" >/dev/null
plutil -lint "$ROOT/resources/ja.lproj/Localizable.strings" >/dev/null
diff \
  <(sed -n 's/^\("[^"]*"\).*/\1/p' "$ROOT/resources/en.lproj/Localizable.strings" | sort) \
  <(sed -n 's/^\("[^"]*"\).*/\1/p' "$ROOT/resources/ja.lproj/Localizable.strings" | sort)
"$ROOT/tools/test-limit-rings.sh"

swiftc \
  -parse-as-library \
  -target "arm64-apple-macosx$DEPLOYMENT_TARGET" \
  "$ROOT/tools/codex-pet-limit-rings.swift" \
  -o "$APP_BIN" \
  -framework AppKit \
  -framework UserNotifications \
  -lsqlite3

"$APP_BIN" --preview "$PREVIEW" --size 164
test -s "$PREVIEW"

minimum_os="$(vtool -show-build "$APP_BIN" | awk '$1 == "minos" { print $2; exit }')"
if [[ "$minimum_os" != "$DEPLOYMENT_TARGET" ]]; then
  echo "release verification failed: expected minimum macOS $DEPLOYMENT_TARGET, found ${minimum_os:-unreadable}" >&2
  exit 1
fi

if grep -En 'access_token|Authorization.*Bearer|URLSession\.shared|backend-api/wham/usage' \
  "$ROOT/tools/codex-pet-limit-rings.swift"; then
  echo "release verification failed: legacy credential path remains in app source" >&2
  exit 1
fi

if grep -En 'account/rateLimitResetCredit/consume|account/usage/read|thread/tokenUsage/updated' \
  "$ROOT/tools/codex-pet-limit-rings.swift"; then
  echo "release verification failed: excluded mutation or v0.7 data path found in v0.6 source" >&2
  exit 1
fi

if find "$ROOT" -type f \
  ! -path "$ROOT/.git/*" \
  ! -path "$ROOT/tmp/*" \
  ! -path "$ROOT/docs/assets/*" \
  -exec grep -EIln \
    '(sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16}|-----BEGIN (RSA |OPENSSH |EC )?PRIVATE KEY-----)' \
    {} +; then
  echo "release verification failed: secret-like material found" >&2
  exit 1
fi

grep -q 'MIT License' "$ROOT/LICENSE"
test -f "$ROOT/resources/en.lproj/Localizable.strings"
test -f "$ROOT/resources/ja.lproj/Localizable.strings"

plist_version="$(plutil -extract CFBundleShortVersionString raw "$PLIST")"
source_version="$(sed -n 's/.*var version = "\([^"]*\)".*/\1/p' "$ROOT/tools/codex-pet-limit-rings.swift" | head -1)"
if [[ -z "$source_version" || "$plist_version" != "$source_version" ]]; then
  echo "release verification failed: app-server client version does not match Info.plist" >&2
  exit 1
fi

plist_minimum_os="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"
if [[ "$plist_minimum_os" != "$minimum_os" ]]; then
  echo "release verification failed: Info.plist minimum macOS does not match the binary" >&2
  exit 1
fi

echo "release verification passed for v$plist_version (minimum macOS $minimum_os)"
