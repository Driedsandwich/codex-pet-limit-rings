#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BIN="$ROOT/tmp/codex-pet-limit-rings-release-check"
PREVIEW="$ROOT/tmp/codex-pet-limit-rings-release-check.png"
PATH_SCAN_APP="$ROOT/tmp/codex-pet-limit-rings-path-scan.app"
PATH_SCAN_ZIP="$ROOT/tmp/codex-pet-limit-rings-path-scan.zip"
PATH_SCAN_EXTRACT="$ROOT/tmp/codex-pet-limit-rings-path-scan-extracted"
PATH_SCAN_FIXTURE="$ROOT/tmp/codex-pet-limit-rings-path-scan-fixture"
PLIST="$ROOT/tools/CodexPetLimitRings-Info.plist"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"

contains_local_absolute_path() {
  strings "$1" | grep -E '/Users/[^/[:space:]]+|/home/[^/[:space:]]+|/(private/)?var/folders/'
}

assert_no_local_absolute_paths() {
  local binary="$1"
  if [[ ! -f "$binary" ]]; then
    echo "release verification failed: path-scan binary is missing: $binary" >&2
    exit 1
  fi
  if contains_local_absolute_path "$binary"; then
    echo "release verification failed: local absolute path found in $(basename "$binary")" >&2
    exit 1
  fi
}

mkdir -p "$ROOT/tmp"
printf '/Users/example/repository/source.swift\n' > "$PATH_SCAN_FIXTURE"
if ! contains_local_absolute_path "$PATH_SCAN_FIXTURE" >/dev/null; then
  echo "release verification failed: local absolute path detector rejected its fixture" >&2
  exit 1
fi

bash -n "$ROOT"/tools/*.sh
plutil -lint "$PLIST" >/dev/null
plutil -lint "$ROOT/resources/en.lproj/Localizable.strings" >/dev/null
plutil -lint "$ROOT/resources/ja.lproj/Localizable.strings" >/dev/null
diff \
  <(sed -n 's/^\("[^"]*"\).*/\1/p' "$ROOT/resources/en.lproj/Localizable.strings" | sort) \
  <(sed -n 's/^\("[^"]*"\).*/\1/p' "$ROOT/resources/ja.lproj/Localizable.strings" | sort)
"$ROOT/tools/test-limit-rings.sh"

(
  cd "$ROOT"
  swiftc \
    -parse-as-library \
    -target "arm64-apple-macosx$DEPLOYMENT_TARGET" \
    -file-prefix-map "$ROOT=." \
    tools/codex-pet-limit-rings.swift \
    -o "$APP_BIN" \
    -framework AppKit \
    -framework UserNotifications \
    -lsqlite3
)

assert_no_local_absolute_paths "$APP_BIN"

rm -rf "$PATH_SCAN_APP" "$PATH_SCAN_ZIP" "$PATH_SCAN_EXTRACT"
"$ROOT/tools/build-limit-rings.sh" "$PATH_SCAN_APP" >/dev/null
ditto -c -k --norsrc --keepParent "$PATH_SCAN_APP" "$PATH_SCAN_ZIP"
mkdir -p "$PATH_SCAN_EXTRACT"
ditto -x -k "$PATH_SCAN_ZIP" "$PATH_SCAN_EXTRACT"
path_scan_binary="$(find "$PATH_SCAN_EXTRACT" -type f -path '*/Contents/MacOS/CodexPetLimitRings' -print -quit)"
if [[ -z "$path_scan_binary" ]]; then
  echo "release verification failed: packaged app binary is missing after ZIP extraction" >&2
  exit 1
fi
assert_no_local_absolute_paths "$path_scan_binary"

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

if grep -En 'account/rateLimitResetCredit/consume|thread/tokenUsage/updated|thread/(resume|fork|read|list)' \
  "$ROOT/tools/codex-pet-limit-rings.swift"; then
  echo "release verification failed: excluded account mutation or thread data path found" >&2
  exit 1
fi

if grep -En 'UserDefaults[^\n]*dailyUsage|dailyUsage[^\n]*UserDefaults|threadId|turnId' \
  "$ROOT/tools/codex-pet-limit-rings.swift"; then
  echo "release verification failed: daily usage persistence or thread identifiers found" >&2
  exit 1
fi

if grep -En 'UserDefaults[^\n]*(lastLiveRateLimitUpdate|lastFullRateLimitSync|lastRateLimitValueChange|rateLimitSignature)' \
  "$ROOT/tools/codex-pet-limit-rings.swift"; then
  echo "release verification failed: update-cadence diagnostics must remain memory-only" >&2
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
