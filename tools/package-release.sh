#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT/tools/CodexPetLimitRings-Info.plist")"
DIST="$ROOT/dist"
STAGE="$ROOT/tmp/release-v$VERSION"
APP="$STAGE/CodexPetLimitRings.app"
ARCHIVE="$DIST/CodexPetLimitRings-v$VERSION-macos-arm64.zip"
CHECKSUM="$ARCHIVE.sha256"

"$ROOT/tools/verify-release.sh"

rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"
"$ROOT/tools/build-limit-rings.sh" "$APP" >/dev/null

file "$APP/Contents/MacOS/CodexPetLimitRings" | rg -q 'arm64'
codesign --verify --deep --strict "$APP"

rm -f "$ARCHIVE" "$CHECKSUM"
ditto -c -k --norsrc --keepParent "$APP" "$ARCHIVE"
(cd "$DIST" && shasum -a 256 "$(basename "$ARCHIVE")") > "$CHECKSUM.tmp"
mv "$CHECKSUM.tmp" "$CHECKSUM"
(cd "$DIST" && shasum -a 256 -c "$(basename "$CHECKSUM")")

echo "$ARCHIVE"
echo "$CHECKSUM"
