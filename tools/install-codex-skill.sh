#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME_DIR="${CODEX_HOME:-$HOME/.codex}"
TARGET="$CODEX_HOME_DIR/skills/codex-pet-limit-rings"
BACKUP_ROOT="$CODEX_HOME_DIR/backups/codex-pet-limit-rings"

mkdir -p "$CODEX_HOME_DIR/skills"
if [[ -d "$TARGET" ]]; then
  backup="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup"
  cp -R "$TARGET" "$backup/skill"
  echo "Backed up existing Codex skill at $backup/skill"
fi
rm -rf "$TARGET"
cp -R "$ROOT/skills/codex-pet-limit-rings" "$TARGET"

echo "Installed Codex skill at $TARGET"
