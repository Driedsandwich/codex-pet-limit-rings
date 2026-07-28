#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

mkdir -p "$ROOT/tmp"
assert_safe_release_root "$ROOT/tmp"
FIXTURE_ROOT="$ROOT/tmp/release-safety-fixture.$$"
ALLOWED_ROOT="$FIXTURE_ROOT/allowed"
OUTSIDE_ROOT="$FIXTURE_ROOT/outside"
cleanup() {
  if [[ -d "$FIXTURE_ROOT" && ! -L "$FIXTURE_ROOT" ]]; then
    safe_remove_release_path "$FIXTURE_ROOT" "$ROOT/tmp" "$(basename "$FIXTURE_ROOT")"
  fi
}
trap cleanup EXIT
mkdir -p "$ALLOWED_ROOT" "$OUTSIDE_ROOT"
assert_safe_release_root "$ALLOWED_ROOT"

expect_rejected() {
  if "$@" >/dev/null 2>&1; then
    echo "release safety tests failed: dangerous input was accepted: $*" >&2
    exit 1
  fi
}

safe_app="$ALLOWED_ROOT/nested/CodexPetLimitRings.app"
mkdir -p "$safe_app"
assert_safe_app_path "$safe_app" "CodexPetLimitRings.app" "$ALLOWED_ROOT"
safe_remove_app_bundle "$safe_app" "CodexPetLimitRings.app" "$ALLOWED_ROOT"
test ! -e "$safe_app"

expect_rejected assert_safe_app_path "/" "CodexPetLimitRings.app" "$ALLOWED_ROOT"
expect_rejected assert_safe_app_path "$HOME" "$(basename "$HOME")" "$HOME"
expect_rejected assert_safe_app_path "$OUTSIDE_ROOT/CodexPetLimitRings.app" "CodexPetLimitRings.app" "$ALLOWED_ROOT"
expect_rejected assert_safe_app_path "$ALLOWED_ROOT/../CodexPetLimitRings.app" "CodexPetLimitRings.app" "$ALLOWED_ROOT"
expect_rejected assert_safe_app_path "$ALLOWED_ROOT/Wrong.app" "CodexPetLimitRings.app" "$ALLOWED_ROOT"

real_app="$ALLOWED_ROOT/real/CodexPetLimitRings.app"
linked_app="$ALLOWED_ROOT/linked/CodexPetLimitRings.app"
mkdir -p "$real_app" "$(dirname "$linked_app")"
touch "$real_app/sentinel"
ln -s "$real_app" "$linked_app"
expect_rejected safe_remove_app_bundle "$linked_app" "CodexPetLimitRings.app" "$ALLOWED_ROOT"
test -f "$real_app/sentinel"

checksum_fixture="$FIXTURE_ROOT/checksum"
printf 'release safety fixture\n' > "$checksum_fixture"
checksum="$(sha256_of "$checksum_fixture")"
assert_file_sha256 "$checksum_fixture" "$checksum" "fixture"
expect_rejected assert_file_sha256 "$checksum_fixture" "$(printf '0%.0s' {1..64})" "fixture"
expect_rejected assert_file_sha256 "$checksum_fixture" "invalid" "fixture"

launch_agent_app="$ALLOWED_ROOT/CodexPetLimitRings.app"
launch_agent_fixture="$FIXTURE_ROOT/com.codex-pet.limit-rings.plist"
mkdir -p "$launch_agent_app"
plutil -create xml1 "$launch_agent_fixture"
plutil -insert Label -string com.codex-pet.limit-rings "$launch_agent_fixture"
plutil -insert ProgramArguments \
  -json "[\"/usr/bin/open\",\"-W\",\"$launch_agent_app\"]" \
  "$launch_agent_fixture"
plutil -insert RunAtLoad -bool true "$launch_agent_fixture"
plutil -insert LimitLoadToSessionType -string Aqua "$launch_agent_fixture"
assert_launch_agent_contract "$launch_agent_fixture" "$launch_agent_app"

direct_binary_agent="$FIXTURE_ROOT/direct-binary-agent.plist"
cp "$launch_agent_fixture" "$direct_binary_agent"
plutil -replace ProgramArguments.0 \
  -string "$launch_agent_app/Contents/MacOS/CodexPetLimitRings" \
  "$direct_binary_agent"
expect_rejected assert_launch_agent_contract "$direct_binary_agent" "$launch_agent_app"

extra_argument_agent="$FIXTURE_ROOT/extra-argument-agent.plist"
cp "$launch_agent_fixture" "$extra_argument_agent"
plutil -insert ProgramArguments.3 -string unexpected "$extra_argument_agent"
expect_rejected assert_launch_agent_contract "$extra_argument_agent" "$launch_agent_app"

linked_agent="$FIXTURE_ROOT/linked-agent.plist"
ln -s "$launch_agent_fixture" "$linked_agent"
expect_rejected assert_launch_agent_contract "$linked_agent" "$launch_agent_app"

assert_release_version 1.0.10
expect_rejected assert_release_version ""
expect_rejected assert_release_version 1.0
expect_rejected assert_release_version '1.0.10/../../outside'

assert_legacy_local_path_exception \
  1 \
  "$PINNED_LEGACY_LOCAL_PATH_VERSION" \
  "$PINNED_LEGACY_LOCAL_PATH_SHA256"
assert_legacy_local_path_exception 0 9.9.9 ""
expect_rejected assert_legacy_local_path_exception 1 1.0.1 "$PINNED_LEGACY_LOCAL_PATH_SHA256"
expect_rejected assert_legacy_local_path_exception 1 "$PINNED_LEGACY_LOCAL_PATH_VERSION" \
  "$(printf '0%.0s' {1..64})"
expect_rejected assert_legacy_local_path_exception 1 "$PINNED_LEGACY_LOCAL_PATH_VERSION" ""
expect_rejected assert_legacy_local_path_exception 2 "$PINNED_LEGACY_LOCAL_PATH_VERSION" \
  "$PINNED_LEGACY_LOCAL_PATH_SHA256"
expect_rejected env \
  ALLOW_LEGACY_LOCAL_PATHS=1 \
  EXPECTED_SHA256="$PINNED_LEGACY_LOCAL_PATH_SHA256" \
  "$ROOT/tools/smoke-release-artifact.sh" 1.0.1 --inspect-only
expect_rejected env \
  ALLOW_LEGACY_LOCAL_PATHS=1 \
  EXPECTED_SHA256="$(printf '0%.0s' {1..64})" \
  "$ROOT/tools/smoke-release-artifact.sh" "$PINNED_LEGACY_LOCAL_PATH_VERSION" --inspect-only

multi_line_archive="$FIXTURE_ROOT/CodexPetLimitRings-v1.0.10-macos-arm64.zip"
multi_line_checksum="$multi_line_archive.sha256"
printf 'not an archive\n' > "$multi_line_archive"
printf '%s  %s\n%s  %s\n' \
  "$(sha256_of "$multi_line_archive")" \
  "$(basename "$multi_line_archive")" \
  "$(sha256_of "$multi_line_archive")" \
  "$(basename "$multi_line_archive")" \
  > "$multi_line_checksum"
expect_rejected \
  "$ROOT/tools/verify-release-artifact.sh" \
  1.0.10 \
  "$multi_line_archive" \
  "$multi_line_checksum" \
  --inspect-only

release_workspace="$ALLOWED_ROOT/release-v1.0.10"
mkdir -p "$release_workspace"
assert_safe_release_path "$release_workspace" "$ALLOWED_ROOT" "release-v1.0.10"
safe_remove_release_path "$release_workspace" "$ALLOWED_ROOT" "release-v1.0.10"
test ! -e "$release_workspace"
expect_rejected assert_safe_release_path "/" "$ALLOWED_ROOT" "release-v1.0.10"
expect_rejected assert_safe_release_path "$ALLOWED_ROOT/../release-v1.0.10" \
  "$ALLOWED_ROOT" "release-v1.0.10"
expect_rejected assert_safe_release_path "$OUTSIDE_ROOT/release-v1.0.10" \
  "$ALLOWED_ROOT" "release-v1.0.10"
expect_rejected assert_safe_release_path "$ALLOWED_ROOT/release-v1.0.9" \
  "$ALLOWED_ROOT" "release-v1.0.10"

real_release_workspace="$ALLOWED_ROOT/real-release-v1.0.10"
linked_release_workspace="$ALLOWED_ROOT/release-v1.0.10"
mkdir -p "$real_release_workspace"
touch "$real_release_workspace/sentinel"
ln -s "$real_release_workspace" "$linked_release_workspace"
expect_rejected safe_remove_release_path "$linked_release_workspace" \
  "$ALLOWED_ROOT" "release-v1.0.10"
test -f "$real_release_workspace/sentinel"
rm "$linked_release_workspace"

linked_root="$FIXTURE_ROOT/linked-root"
ln -s "$ALLOWED_ROOT" "$linked_root"
expect_rejected assert_safe_release_root "$linked_root"
expect_rejected assert_safe_release_path "$linked_root/release-v1.0.10" \
  "$linked_root" "release-v1.0.10"

english="$FIXTURE_ROOT/en.strings"
japanese="$FIXTURE_ROOT/ja.strings"
printf '"message" = "Value %%@ %%d";\n' > "$english"
printf '"message" = "値 %%@ %%d";\n' > "$japanese"
verify_localization_contract "$english" "$japanese" "$FIXTURE_ROOT"

printf '"message" = "値 %%@";\n' > "$japanese"
expect_rejected verify_localization_contract "$english" "$japanese" "$FIXTURE_ROOT"

printf '"message" = "値 %%@ %%d";\n"message" = "重複 %%@ %%d";\n' > "$japanese"
expect_rejected verify_localization_contract "$english" "$japanese" "$FIXTURE_ROOT"

echo "release safety tests passed"
