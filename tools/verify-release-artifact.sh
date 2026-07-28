#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

VERSION="${1:-}"
ARCHIVE="${2:-}"
CHECKSUM="${3:-}"
MODE="${4:-run}"
ALLOW_LEGACY_LOCAL_PATHS="${ALLOW_LEGACY_LOCAL_PATHS:-0}"

assert_release_version "$VERSION"
if [[ -z "$ARCHIVE" || ! -f "$ARCHIVE" || -z "$CHECKSUM" || ! -f "$CHECKSUM" ]]; then
  echo "artifact verification failed: archive and checksum files are required" >&2
  exit 2
fi
if [[ -L "$ARCHIVE" || -L "$CHECKSUM" ]]; then
  echo "artifact verification failed: archive and checksum must not be symbolic links" >&2
  exit 1
fi
if [[ "$MODE" != "run" && "$MODE" != "--inspect-only" ]]; then
  echo "artifact verification failed: invalid mode '$MODE'" >&2
  exit 2
fi
if [[ -n "${EXPECTED_SHA256:-}" && ! "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "artifact verification failed: EXPECTED_SHA256 must be a lowercase SHA-256 digest" >&2
  exit 2
fi
assert_legacy_local_path_exception \
  "$ALLOW_LEGACY_LOCAL_PATHS" \
  "$VERSION" \
  "${EXPECTED_SHA256:-}"

ARCHIVE_NAME="CodexPetLimitRings-v$VERSION-macos-arm64.zip"
CHECKSUM_NAME="$ARCHIVE_NAME.sha256"
if [[ "$(basename "$ARCHIVE")" != "$ARCHIVE_NAME" ||
      "$(basename "$CHECKSUM")" != "$CHECKSUM_NAME" ]]; then
  echo "artifact verification failed: artifact filenames do not match v$VERSION" >&2
  exit 1
fi

mkdir -p "$ROOT/tmp"
assert_safe_release_root "$ROOT/tmp"
WORK_DIR="$(mktemp -d "$ROOT/tmp/codex-pet-limit-rings-artifact-v$VERSION.XXXXXX")"
cleanup() {
  if [[ -d "$WORK_DIR" && ! -L "$WORK_DIR" ]]; then
    safe_remove_release_path "$WORK_DIR" "$ROOT/tmp" "$(basename "$WORK_DIR")"
  fi
}
trap cleanup EXIT

checksum_line_count="$(awk 'END { print NR + 0 }' "$CHECKSUM")"
if [[ "$checksum_line_count" != "1" ]]; then
  echo "artifact verification failed: checksum file must contain exactly one line" >&2
  exit 1
fi
read -r recorded_sha recorded_name extra < "$CHECKSUM"
if [[ ! "$recorded_sha" =~ ^[0-9a-f]{64}$ ||
      "$recorded_name" != "$ARCHIVE_NAME" ||
      -n "${extra:-}" ]]; then
  echo "artifact verification failed: checksum file has an unexpected format" >&2
  exit 1
fi
assert_file_sha256 "$ARCHIVE" "$recorded_sha" "$ARCHIVE_NAME"
if [[ -n "${EXPECTED_SHA256:-}" ]]; then
  assert_file_sha256 "$ARCHIVE" "$EXPECTED_SHA256" "$ARCHIVE_NAME pinned digest"
fi

ARCHIVE_MANIFEST="$WORK_DIR/archive-manifest.txt"
EXPECTED_MANIFEST="$WORK_DIR/expected-archive-manifest.txt"
zipinfo -1 "$ARCHIVE" | LC_ALL=C sort > "$ARCHIVE_MANIFEST"
cat > "$EXPECTED_MANIFEST" <<'EOF'
CodexPetLimitRings.app/
CodexPetLimitRings.app/Contents/
CodexPetLimitRings.app/Contents/Info.plist
CodexPetLimitRings.app/Contents/MacOS/
CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings
CodexPetLimitRings.app/Contents/Resources/
CodexPetLimitRings.app/Contents/Resources/en.lproj/
CodexPetLimitRings.app/Contents/Resources/en.lproj/Localizable.strings
CodexPetLimitRings.app/Contents/Resources/ja.lproj/
CodexPetLimitRings.app/Contents/Resources/ja.lproj/Localizable.strings
CodexPetLimitRings.app/Contents/_CodeSignature/
CodexPetLimitRings.app/Contents/_CodeSignature/CodeResources
EOF
LC_ALL=C sort -o "$EXPECTED_MANIFEST" "$EXPECTED_MANIFEST"
if ! diff -u "$EXPECTED_MANIFEST" "$ARCHIVE_MANIFEST"; then
  echo "artifact verification failed: archive entries differ from the allowlist" >&2
  exit 1
fi
if zipinfo -l "$ARCHIVE" |
  awk '$1 ~ /^l/ { found = 1 } END { exit(found ? 0 : 1) }'; then
  echo "artifact verification failed: archive contains a symbolic link" >&2
  exit 1
fi

mkdir -p "$WORK_DIR/extracted"
ditto -x -k "$ARCHIVE" "$WORK_DIR/extracted"
APP="$WORK_DIR/extracted/CodexPetLimitRings.app"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
PREVIEW="$WORK_DIR/preview.png"
DIAGNOSTICS="$WORK_DIR/diagnostics.json"
DIAGNOSTIC_ERRORS="$WORK_DIR/diagnostics.stderr"
DIAGNOSTIC_CODEX_HOME="$WORK_DIR/codex-home"

test -d "$APP"
test -x "$BIN"
if [[ -n "$(find "$APP" -type l -print -quit)" ]]; then
  echo "artifact verification failed: extracted app contains a symbolic link" >&2
  exit 1
fi
codesign --verify --deep --strict "$APP"
file "$BIN" | grep -q 'arm64'
test -f "$APP/Contents/Resources/en.lproj/Localizable.strings"
test -f "$APP/Contents/Resources/ja.lproj/Localizable.strings"
plutil -lint "$APP/Contents/Resources/en.lproj/Localizable.strings" >/dev/null
plutil -lint "$APP/Contents/Resources/ja.lproj/Localizable.strings" >/dev/null
verify_localization_contract \
  "$APP/Contents/Resources/en.lproj/Localizable.strings" \
  "$APP/Contents/Resources/ja.lproj/Localizable.strings" \
  "$WORK_DIR"

bundle_identifier="$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")"
if [[ "$bundle_identifier" != "local.codex.pet-limit-rings" ]]; then
  echo "artifact verification failed: unexpected bundle identifier '$bundle_identifier'" >&2
  exit 1
fi
if [[ "$ALLOW_LEGACY_LOCAL_PATHS" == "1" ]]; then
  echo "legacy local-path exception accepted for pinned v$VERSION provenance artifact"
else
  assert_no_local_absolute_paths "$BIN"
fi

minimum_os="$(vtool -show-build "$BIN" | awk '$1 == "minos" { print $2; exit }')"
if [[ -z "$minimum_os" ]]; then
  echo "artifact verification failed: minimum macOS version is unreadable" >&2
  exit 1
fi
if [[ -n "${EXPECTED_MIN_OS:-}" && "$minimum_os" != "$EXPECTED_MIN_OS" ]]; then
  echo "artifact verification failed: expected minimum macOS $EXPECTED_MIN_OS, found $minimum_os" >&2
  exit 1
fi

artifact_version="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
if [[ "$artifact_version" != "$VERSION" ]]; then
  echo "artifact verification failed: expected v$VERSION, found v$artifact_version" >&2
  exit 1
fi

if [[ "$MODE" == "run" ]]; then
  "$BIN" --preview "$PREVIEW" --size 164
  test -s "$PREVIEW"
  mkdir -p "$DIAGNOSTIC_CODEX_HOME"
  "$BIN" \
    --diagnose \
    --codex-home "$DIAGNOSTIC_CODEX_HOME" \
    --state "$DIAGNOSTIC_CODEX_HOME/.codex-global-state.json" \
    --logs "$DIAGNOSTIC_CODEX_HOME/logs.sqlite" \
    > "$DIAGNOSTICS" \
    2> "$DIAGNOSTIC_ERRORS"
  plutil -convert xml1 -o /dev/null "$DIAGNOSTICS"
  if grep -aE \
    '(/Users/[^/[:space:]"]+|/home/[^/[:space:]"]+|/(private/)?var/folders/|sk-[A-Za-z0-9_-]{20,}|ghp_[A-Za-z0-9]{20,}|access_token|Authorization.*Bearer|account[_-]?(id|identifier)|user[_-]?(id|identifier)|email)' \
    "$DIAGNOSTICS" "$DIAGNOSTIC_ERRORS"; then
    echo "artifact verification failed: diagnostics contain private data or a local path" >&2
    exit 1
  fi
else
  echo "artifact execution skipped; static inspection found minimum macOS $minimum_os"
fi

echo "release artifact verification passed for v$VERSION (minimum macOS $minimum_os)"
