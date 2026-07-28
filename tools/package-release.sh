#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"
assert_release_version "$VERSION"
DIST="$ROOT/dist"
STAGE="$ROOT/tmp/release-v$VERSION"
APP="$STAGE/CodexPetLimitRings.app"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
PREVIEW="$STAGE/package-preview.png"
ARCHIVE="$DIST/CodexPetLimitRings-v$VERSION-macos-arm64.zip"
CHECKSUM="$ARCHIVE.sha256"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"

"$ROOT/tools/verify-release.sh"

mkdir -p "$ROOT/tmp" "$DIST"
assert_safe_release_root "$ROOT/tmp"
assert_safe_release_root "$DIST"
assert_safe_release_path "$STAGE" "$ROOT/tmp" "release-v$VERSION"
safe_remove_release_path "$STAGE" "$ROOT/tmp" "release-v$VERSION"
mkdir -p "$STAGE"
"$ROOT/tools/build-limit-rings.sh" "$APP" >/dev/null

file "$BIN" | grep -q 'arm64'
codesign --verify --deep --strict "$APP"
test -f "$APP/Contents/Resources/en.lproj/Localizable.strings"
test -f "$APP/Contents/Resources/ja.lproj/Localizable.strings"
minimum_os="$(vtool -show-build "$BIN" | awk '$1 == "minos" { print $2; exit }')"
if [[ "$minimum_os" != "$DEPLOYMENT_TARGET" ]]; then
  echo "release packaging failed: expected minimum macOS $DEPLOYMENT_TARGET, found ${minimum_os:-unreadable}" >&2
  exit 1
fi
"$BIN" --preview "$PREVIEW" --size 164
test -s "$PREVIEW"

assert_safe_release_path "$ARCHIVE" "$DIST" "$(basename "$ARCHIVE")"
assert_safe_release_path "$CHECKSUM" "$DIST" "$(basename "$CHECKSUM")"
assert_safe_release_path "$CHECKSUM.tmp" "$DIST" "$(basename "$CHECKSUM.tmp")"
safe_remove_release_path "$ARCHIVE" "$DIST" "$(basename "$ARCHIVE")"
safe_remove_release_path "$CHECKSUM" "$DIST" "$(basename "$CHECKSUM")"
safe_remove_release_path "$CHECKSUM.tmp" "$DIST" "$(basename "$CHECKSUM.tmp")"
ditto -c -k --norsrc --keepParent "$APP" "$ARCHIVE"
(cd "$DIST" && shasum -a 256 "$(basename "$ARCHIVE")") > "$CHECKSUM.tmp"
mv "$CHECKSUM.tmp" "$CHECKSUM"
(cd "$DIST" && shasum -a 256 -c "$(basename "$CHECKSUM")")
EXPECTED_MIN_OS="$DEPLOYMENT_TARGET" \
  "$ROOT/tools/verify-release-artifact.sh" \
  "$VERSION" \
  "$ARCHIVE" \
  "$CHECKSUM"

echo "$ARCHIVE"
echo "$CHECKSUM"
