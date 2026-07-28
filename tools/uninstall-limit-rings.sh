#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

APP="${CODEX_PET_LIMIT_RINGS_APP:-$HOME/Applications/CodexPetLimitRings.app}"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
AGENT="$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
OLD_APP="${CODEX_LIMIT_AURA_APP:-$HOME/Applications/CodexLimitAura.app}"
OLD_BIN="$OLD_APP/Contents/MacOS/CodexLimitAura"
OLD_AGENT="$HOME/Library/LaunchAgents/com.codex-pet.limit-aura.plist"
GUI_TARGET="gui/$(id -u)"

assert_safe_app_path "$APP" "CodexPetLimitRings.app" "$HOME/Applications"
assert_safe_app_path "$OLD_APP" "CodexLimitAura.app" "$HOME/Applications"

launchctl bootout "$GUI_TARGET" "$AGENT" >/dev/null 2>&1 || true
launchctl bootout "$GUI_TARGET" "$OLD_AGENT" >/dev/null 2>&1 || true
pkill -TERM -f "$BIN" >/dev/null 2>&1 || true
pkill -TERM -f "$OLD_BIN" >/dev/null 2>&1 || true
pkill -TERM -f "CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" >/dev/null 2>&1 || true
pkill -TERM -f "CodexLimitAura.app/Contents/MacOS/CodexLimitAura" >/dev/null 2>&1 || true
rm -f "$AGENT"
rm -f "$OLD_AGENT"
safe_remove_app_bundle "$APP" "CodexPetLimitRings.app" "$HOME/Applications"
safe_remove_app_bundle "$OLD_APP" "CodexLimitAura.app" "$HOME/Applications"
defaults delete local.codex.pet-limit-rings CodexPetLimitRings.ringsVisible >/dev/null 2>&1 || true
defaults delete local.codex.pet-limit-rings CodexPetLimitRings.notificationsEnabled >/dev/null 2>&1 || true
defaults delete local.codex.pet-limit-rings CodexPetLimitRings.notificationBands >/dev/null 2>&1 || true
defaults delete local.codex.limit-aura CodexLimitAura.ringsVisible >/dev/null 2>&1 || true

echo "Codex Pet Limit Rings uninstalled"
