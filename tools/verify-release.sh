#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

PLIST="$ROOT/tools/CodexPetLimitRings-Info.plist"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$PLIST")"
assert_release_version "$VERSION"
VERIFY_ROOT="$ROOT/tmp/verify-release-v$VERSION"
APP_BIN="$VERIFY_ROOT/codex-pet-limit-rings-release-check"
PREVIEW="$VERIFY_ROOT/codex-pet-limit-rings-release-check.png"
PATH_SCAN_STAGE="$VERIFY_ROOT/package"
PATH_SCAN_APP="$PATH_SCAN_STAGE/CodexPetLimitRings.app"
PATH_SCAN_ZIP="$VERIFY_ROOT/CodexPetLimitRings-v$VERSION-macos-arm64.zip"
PATH_SCAN_CHECKSUM="$PATH_SCAN_ZIP.sha256"
PATH_SCAN_FIXTURE="$VERIFY_ROOT/codex-pet-limit-rings-path-scan-fixture"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$PLIST")"

mkdir -p "$ROOT/tmp"
assert_safe_release_root "$ROOT/tmp"
assert_safe_release_path "$VERIFY_ROOT" "$ROOT/tmp" "verify-release-v$VERSION"
safe_remove_release_path "$VERIFY_ROOT" "$ROOT/tmp" "verify-release-v$VERSION"
mkdir -p "$VERIFY_ROOT"
cleanup() {
  if [[ -d "$VERIFY_ROOT" && ! -L "$VERIFY_ROOT" ]]; then
    safe_remove_release_path "$VERIFY_ROOT" "$ROOT/tmp" "verify-release-v$VERSION"
  fi
}
trap cleanup EXIT

printf '/Users/example/repository/source.swift\n' > "$PATH_SCAN_FIXTURE"
if ! contains_local_absolute_path "$PATH_SCAN_FIXTURE" >/dev/null; then
  echo "release verification failed: local absolute path detector rejected its fixture" >&2
  exit 1
fi

bash -n "$ROOT"/tools/*.sh
plutil -lint "$PLIST" >/dev/null
plutil -lint "$ROOT/resources/en.lproj/Localizable.strings" >/dev/null
plutil -lint "$ROOT/resources/ja.lproj/Localizable.strings" >/dev/null
"$ROOT/tools/test-release-safety.sh"
verify_localization_contract \
  "$ROOT/resources/en.lproj/Localizable.strings" \
  "$ROOT/resources/ja.lproj/Localizable.strings" \
  "$ROOT/tmp"
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

"$ROOT/tools/build-limit-rings.sh" "$PATH_SCAN_APP" >/dev/null
codesign --verify --deep --strict "$PATH_SCAN_APP"
ditto -c -k --norsrc --keepParent "$PATH_SCAN_APP" "$PATH_SCAN_ZIP"
(
  cd "$VERIFY_ROOT"
  shasum -a 256 "$(basename "$PATH_SCAN_ZIP")"
) > "$PATH_SCAN_CHECKSUM"
EXPECTED_MIN_OS="$DEPLOYMENT_TARGET" \
  "$ROOT/tools/verify-release-artifact.sh" \
  "$VERSION" \
  "$PATH_SCAN_ZIP" \
  "$PATH_SCAN_CHECKSUM"

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

plist_version="$VERSION"
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
