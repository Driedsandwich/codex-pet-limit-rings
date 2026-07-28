#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

VERSION="${1:-0.5.1}"
MODE="${2:-run}"
REPOSITORY="${RELEASE_REPOSITORY:-Driedsandwich/codex-pet-limit-rings}"
ALLOW_LEGACY_LOCAL_PATHS="${ALLOW_LEGACY_LOCAL_PATHS:-0}"

assert_release_version "$VERSION"

if [[ "$MODE" != "run" && "$MODE" != "--inspect-only" ]]; then
  echo "artifact smoke test failed: invalid mode '$MODE'" >&2
  exit 2
fi

if [[ -n "${EXPECTED_SHA256:-}" && ! "$EXPECTED_SHA256" =~ ^[0-9a-f]{64}$ ]]; then
  echo "artifact smoke test failed: EXPECTED_SHA256 must be a lowercase SHA-256 digest" >&2
  exit 2
fi
assert_legacy_local_path_exception \
  "$ALLOW_LEGACY_LOCAL_PATHS" \
  "$VERSION" \
  "${EXPECTED_SHA256:-}"

ARCHIVE_NAME="CodexPetLimitRings-v$VERSION-macos-arm64.zip"
CHECKSUM_NAME="$ARCHIVE_NAME.sha256"
BASE_URL="https://github.com/$REPOSITORY/releases/download/v$VERSION"
mkdir -p "$ROOT/tmp"
assert_safe_release_root "$ROOT/tmp"
WORK_DIR="$(mktemp -d "$ROOT/tmp/codex-pet-limit-rings-smoke-v$VERSION.XXXXXX")"
cleanup() {
  if [[ -d "$WORK_DIR" && ! -L "$WORK_DIR" ]]; then
    safe_remove_release_path "$WORK_DIR" "$ROOT/tmp" "$(basename "$WORK_DIR")"
  fi
}
trap cleanup EXIT

curl --proto '=https' --tlsv1.2 -fsSL \
  "$BASE_URL/$ARCHIVE_NAME" \
  -o "$WORK_DIR/$ARCHIVE_NAME"
curl --proto '=https' --tlsv1.2 -fsSL \
  "$BASE_URL/$CHECKSUM_NAME" \
  -o "$WORK_DIR/$CHECKSUM_NAME"

"$ROOT/tools/verify-release-artifact.sh" \
  "$VERSION" \
  "$WORK_DIR/$ARCHIVE_NAME" \
  "$WORK_DIR/$CHECKSUM_NAME" \
  "$MODE"

echo "published artifact smoke test passed for v$VERSION"
