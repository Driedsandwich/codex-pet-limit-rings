#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"
DIST="$ROOT/dist"
STAGE="$ROOT/tmp/release-v$VERSION"
APP="$STAGE/CodexPetLimitRings.app"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
PREVIEW="$STAGE/package-preview.png"
ARCHIVE="$DIST/CodexPetLimitRings-v$VERSION-macos-arm64.zip"
CHECKSUM="$ARCHIVE.sha256"
DEPLOYMENT_TARGET="$(plutil -extract LSMinimumSystemVersion raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"

"$ROOT/tools/verify-release.sh"

rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
"$ROOT/tools/build-limit-rings.sh" "$APP" >/dev/null

file "$BIN" | grep -q 'arm64'
codesign --verify --deep --strict "$APP"
minimum_os="$(vtool -show-build "$BIN" | awk '$1 == "minos" { print $2; exit }')"
if [[ "$minimum_os" != "$DEPLOYMENT_TARGET" ]]; then
  echo "release packaging failed: expected minimum macOS $DEPLOYMENT_TARGET, found ${minimum_os:-unreadable}" >&2
  exit 1
fi
"$BIN" --preview "$PREVIEW" --size 164
test -s "$PREVIEW"

rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --norsrc --keepParent "$APP" "$ARCHIVE"
(cd "$DIST" && shasum -a 256 "$(basename "$ARCHIVE")") > "$CHECKSUM.tmp"
mv "$CHECKSUM.tmp" "$CHECKSUM"
(cd "$DIST" && shasum -a 256 -c "$(basename "$CHECKSUM")")

echo "$ARCHIVE"
echo "$CHECKSUM"
