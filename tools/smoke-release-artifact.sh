#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.5.0}"
REPOSITORY="${RELEASE_REPOSITORY:-Driedsandwich/codex-pet-limit-rings}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "artifact smoke test failed: invalid version '$VERSION'" >&2
  exit 2
fi

ARCHIVE_NAME="CodexPetLimitRings-v$VERSION-macos-arm64.zip"
CHECKSUM_NAME="$ARCHIVE_NAME.sha256"
BASE_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-pet-limit-rings-smoke.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

curl --proto '=https' --tlsv1.2 -fsSL \
  "$BASE_URL/$ARCHIVE_NAME" \
  -o "$WORK_DIR/$ARCHIVE_NAME"
curl --proto '=https' --tlsv1.2 -fsSL \
  "$BASE_URL/$CHECKSUM_NAME" \
  -o "$WORK_DIR/$CHECKSUM_NAME"

(cd "$WORK_DIR" && shasum -a 256 -c "$CHECKSUM_NAME")

if unzip -l "$WORK_DIR/$ARCHIVE_NAME" | grep -q '__MACOSX'; then
  echo "artifact smoke test failed: archive contains __MACOSX metadata" >&2
  exit 1
fi

mkdir -p "$WORK_DIR/extracted"
ditto -x -k "$WORK_DIR/$ARCHIVE_NAME" "$WORK_DIR/extracted"
APP="$WORK_DIR/extracted/CodexPetLimitRings.app"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
PREVIEW="$WORK_DIR/preview.png"

test -d "$APP"
test -x "$BIN"
codesign --verify --deep --strict "$APP"
file "$BIN" | grep -q 'arm64'

artifact_version="$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")"
if [[ "$artifact_version" != "$VERSION" ]]; then
  echo "artifact smoke test failed: expected v$VERSION, found v$artifact_version" >&2
  exit 1
fi

"$BIN" --preview "$PREVIEW" --size 164
test -s "$PREVIEW"

echo "published artifact smoke test passed for v$VERSION"
