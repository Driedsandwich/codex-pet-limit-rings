# Rollback

Use this procedure when a newly installed Codex Pet Limit Rings build fails its runtime checks. Keep both the pre-update backup and the failed build until the restored installation passes diagnostics.

## Before Updating

Create one timestamped backup that represents the complete pre-update state. Missing optional artifacts are left absent so rollback can restore that absence instead of inventing state.

```bash
set -euo pipefail

backup="$HOME/Library/Application Support/CodexPetLimitRings/Backups/$(date +%Y%m%d-%H%M%S)"
app="$HOME/Applications/CodexPetLimitRings.app"
agent="$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
skill="${CODEX_HOME:-$HOME/.codex}/skills/codex-pet-limit-rings"

mkdir -p "$backup"
if [[ -d "$app" ]]; then
  ditto "$app" "$backup/CodexPetLimitRings.app"
fi
if [[ -f "$agent" ]]; then
  cp -a "$agent" "$backup/com.codex-pet.limit-rings.plist"
fi
if defaults read local.codex.pet-limit-rings >/dev/null 2>&1; then
  defaults export local.codex.pet-limit-rings "$backup/preferences.plist" >/dev/null
fi
if [[ -d "$skill" ]]; then
  ditto "$skill" "$backup/skill"
fi
printf 'Rollback backup: %s\n' "$backup"
```

Record the printed backup directory before continuing.

## Restore A Backup

Set `backup` to the directory recorded above. The procedure first moves the current failed state into a separate timestamped directory, then restores only artifacts that existed in the pre-update backup. App bundles and Skills are restored into empty destinations with `ditto`; they are not merged into newer directories.

```bash
set -euo pipefail

backup="/path/printed/by/the/backup/command"
failed="$HOME/Library/Application Support/CodexPetLimitRings/FailedBuilds/$(date +%Y%m%d-%H%M%S)"
app="$HOME/Applications/CodexPetLimitRings.app"
agent="$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
skill="${CODEX_HOME:-$HOME/.codex}/skills/codex-pet-limit-rings"
gui="gui/$(id -u)"
label="$gui/com.codex-pet.limit-rings"

test -d "$backup"
mkdir -p "$failed" "$(dirname "$app")" "$(dirname "$agent")" "$(dirname "$skill")"

if launchctl print "$label" >/dev/null 2>&1; then
  launchctl bootout "$gui" "$agent" >/dev/null
fi
pkill_status=0
pkill -TERM -f 'CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings' \
  >/dev/null 2>&1 || pkill_status=$?
if ((pkill_status != 0 && pkill_status != 1)); then
  exit "$pkill_status"
fi

if [[ -d "$app" ]]; then
  mv "$app" "$failed/CodexPetLimitRings.app"
fi
if [[ -f "$agent" ]]; then
  mv "$agent" "$failed/com.codex-pet.limit-rings.plist"
fi
if defaults read local.codex.pet-limit-rings >/dev/null 2>&1; then
  defaults export local.codex.pet-limit-rings "$failed/preferences.plist" >/dev/null
  defaults delete local.codex.pet-limit-rings
fi
if [[ -d "$skill" ]]; then
  mv "$skill" "$failed/skill"
fi

if [[ -d "$backup/CodexPetLimitRings.app" ]]; then
  ditto "$backup/CodexPetLimitRings.app" "$app"
fi
if [[ -f "$backup/com.codex-pet.limit-rings.plist" ]]; then
  cp -a "$backup/com.codex-pet.limit-rings.plist" "$agent"
fi
if [[ -f "$backup/preferences.plist" ]]; then
  defaults import local.codex.pet-limit-rings "$backup/preferences.plist"
fi
if [[ -d "$backup/skill" ]]; then
  ditto "$backup/skill" "$skill"
fi

if [[ -f "$agent" ]]; then
  launchctl bootstrap "$gui" "$agent"
  launchctl kickstart -k "$gui/com.codex-pet.limit-rings"
elif [[ -d "$app" ]]; then
  open "$app"
fi

printf 'Failed build retained at: %s\n' "$failed"
```

Rolling back to a release before v0.6.0 also requires removing the notification preferences introduced in v0.6.0:

```bash
set -euo pipefail

if defaults read local.codex.pet-limit-rings CodexPetLimitRings.notificationsEnabled \
  >/dev/null 2>&1; then
  defaults delete local.codex.pet-limit-rings CodexPetLimitRings.notificationsEnabled
fi
if defaults read local.codex.pet-limit-rings CodexPetLimitRings.notificationBands \
  >/dev/null 2>&1; then
  defaults delete local.codex.pet-limit-rings CodexPetLimitRings.notificationBands
fi
```

Daily usage, aggregate milestones, connection cadence, safe failure reasons, and manual refresh history are memory-only. They do not require a database, JSONL, or cache migration during rollback.

## Verify The Restore

```bash
set -euo pipefail

app="$HOME/Applications/CodexPetLimitRings.app"
if [[ -d "$app" ]]; then
  plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist"
  pgrep -fl CodexPetLimitRings
  if [[ -f "$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist" ]]; then
    launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
  fi
  "$app/Contents/MacOS/CodexPetLimitRings" --diagnose
else
  echo "No pre-update app was present; rollback restored the uninstalled state."
fi
```

Confirm that the restored version, LaunchAgent state when present, pet alignment, and privacy-safe diagnostics match the intended prior release. Cleanup of the failed build and backup is a separate decision after the restore is verified.
