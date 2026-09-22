#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/tools/release-safety.sh"

APP="${CODEX_PET_LIMIT_RINGS_APP:-$HOME/Applications/CodexPetLimitRings.app}"
BIN="$APP/Contents/MacOS/CodexPetLimitRings"
AGENT_DIR="$HOME/Library/LaunchAgents"
AGENT="$AGENT_DIR/com.codex-pet.limit-rings.plist"
OLD_APP="${CODEX_LIMIT_AURA_APP:-$HOME/Applications/CodexLimitAura.app}"
OLD_BIN="$OLD_APP/Contents/MacOS/CodexLimitAura"
OLD_AGENT="$AGENT_DIR/com.codex-pet.limit-aura.plist"
GUI_TARGET="gui/$(id -u)"
BACKUP_ROOT="$HOME/Library/Application Support/CodexPetLimitRings/Backups"
SKILL="${CODEX_HOME:-$HOME/.codex}/skills/codex-pet-limit-rings"

assert_safe_app_path "$APP" "CodexPetLimitRings.app" "$HOME/Applications"
assert_safe_app_path "$OLD_APP" "CodexLimitAura.app" "$HOME/Applications"

# Build and verify before touching the running installation. Failed compilation
# or signing leaves the installed app and its LaunchAgent untouched.
mkdir -p "$ROOT/tmp"
assert_safe_release_root "$ROOT/tmp"
INSTALL_STAGE="$(mktemp -d "$ROOT/tmp/install.XXXXXX")"
STAGED_APP="$INSTALL_STAGE/CodexPetLimitRings.app"
STAGED_AGENT="$INSTALL_STAGE/com.codex-pet.limit-rings.plist"
cleanup() {
  if [[ -d "$INSTALL_STAGE" && ! -L "$INSTALL_STAGE" ]]; then
    safe_remove_release_path "$INSTALL_STAGE" "$ROOT/tmp" "$(basename "$INSTALL_STAGE")"
  fi
}
trap cleanup EXIT
"$ROOT/tools/build-limit-rings.sh" "$STAGED_APP" >/dev/null
codesign --verify --deep --strict "$STAGED_APP"
write_launch_agent "$STAGED_AGENT" "$APP" "$HOME/Library/Logs"

mkdir -p "$BACKUP_ROOT"
backup="$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S).XXXXXX")"
backup_installation_state "$backup" "$APP" "$AGENT" "$SKILL"
echo "Backed up existing installation at $backup"

mkdir -p "$(dirname "$APP")" "$AGENT_DIR" "$HOME/Library/Logs"

launchctl bootout "$GUI_TARGET" "$AGENT" >/dev/null 2>&1 || true
launchctl bootout "$GUI_TARGET" "$OLD_AGENT" >/dev/null 2>&1 || true
pkill -TERM -f "$BIN" >/dev/null 2>&1 || true
pkill -TERM -f "$OLD_BIN" >/dev/null 2>&1 || true
pkill -TERM -f "CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" >/dev/null 2>&1 || true
pkill -TERM -f "CodexLimitAura.app/Contents/MacOS/CodexLimitAura" >/dev/null 2>&1 || true
rm -f "$OLD_AGENT"
safe_remove_app_bundle "$OLD_APP" "CodexLimitAura.app" "$HOME/Applications"

safe_remove_app_bundle "$APP" "CodexPetLimitRings.app" "$HOME/Applications"
ditto "$STAGED_APP" "$APP"
codesign --verify --deep --strict "$APP"

cp "$STAGED_AGENT" "$AGENT"
assert_launch_agent_contract "$AGENT" "$APP"

launchctl bootstrap "$GUI_TARGET" "$AGENT"
launchctl kickstart -k "$GUI_TARGET/com.codex-pet.limit-rings"

echo "Codex Pet Limit Rings installed at $APP"
echo "Menu bar item: Codex Pet Limit Rings icon"
