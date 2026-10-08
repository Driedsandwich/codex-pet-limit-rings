# Verified Installation And Rollback

This runbook installs the published Codex Pet Limit Rings v1.0.16 app without trusting an unverified download. It preserves an existing app, LaunchAgent, preferences, and local Skill in one timestamped backup before replacement.

## Published Artifact

- Release: [v1.0.16](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.16)
- Release target: `75a81ac4467dc16b3f4b55e9e3654622b49fcd66`
- ZIP SHA-256: `0518630feb3b8604814df288bb62324075c1b048afff88a10358627a5441fae5`
- Version/build: `1.0.16 / 25`
- Platform: Apple silicon `arm64`, macOS `15.0` or later
- Signing: ad-hoc signed and not notarized

## Download And Verify

```bash
set -euo pipefail

version=1.0.16
expected_sha=0518630feb3b8604814df288bb62324075c1b048afff88a10358627a5441fae5
release_dir="$HOME/Downloads/CodexPetLimitRings-v$version"
base_url="https://github.com/Driedsandwich/codex-pet-limit-rings/releases/download/v$version"

mkdir -p "$release_dir"
cd "$release_dir"
curl --proto '=https' --tlsv1.2 -fLO "$base_url/CodexPetLimitRings-v$version-macos-arm64.zip"
curl --proto '=https' --tlsv1.2 -fLO "$base_url/CodexPetLimitRings-v$version-macos-arm64.zip.sha256"
printf '%s  %s\n' "$expected_sha" "CodexPetLimitRings-v$version-macos-arm64.zip" | shasum -a 256 -c -
shasum -a 256 -c "CodexPetLimitRings-v$version-macos-arm64.zip.sha256"
ditto -x -k "CodexPetLimitRings-v$version-macos-arm64.zip" .
codesign --verify --deep --strict CodexPetLimitRings.app
```

Do not install the app if either checksum or code-signature verification fails. The bundle is not notarized. If macOS blocks its first launch, inspect and approve it from System Settings only after these checks pass.

## Back Up And Install

The following procedure changes the installed app. Run it only after reviewing the backup path and the verified `release_dir` above.

```bash
set -euo pipefail

version=1.0.16
release_dir="${release_dir:-$HOME/Downloads/CodexPetLimitRings-v$version}"
backup_root="$HOME/Library/Application Support/CodexPetLimitRings/Backups"
mkdir -p "$backup_root"
backup="$(mktemp -d "$backup_root/$(date +%Y%m%d-%H%M%S).XXXXXX")"
app="$HOME/Applications/CodexPetLimitRings.app"
agent="$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
skill="${CODEX_HOME:-$HOME/.codex}/skills/codex-pet-limit-rings"
gui="gui/$(id -u)"
label="$gui/com.codex-pet.limit-rings"

mkdir -p "$backup" "$HOME/Applications"
if [[ -f "$agent" ]]; then
  cp -a "$agent" "$backup/com.codex-pet.limit-rings.plist"
fi
if defaults read local.codex.pet-limit-rings >/dev/null 2>&1; then
  defaults export local.codex.pet-limit-rings "$backup/preferences.plist" >/dev/null
fi
if [[ -d "$skill" ]]; then
  ditto "$skill" "$backup/skill"
fi
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
  mv "$app" "$backup/CodexPetLimitRings.app"
fi
printf '%s\n' 'app launch-agent preferences skill' > "$backup/backup-complete-v1"
ditto "$release_dir/CodexPetLimitRings.app" "$app"
# Write the current LaunchServices contract for both fresh and existing installs.
# plutil escapes paths safely, including spaces, ampersands, and quotes.
mkdir -p "$(dirname "$agent")" "$HOME/Library/Logs"
plutil -create xml1 "$agent"
plutil -insert Label -string com.codex-pet.limit-rings "$agent"
plutil -insert ProgramArguments -json '[]' "$agent"
plutil -insert ProgramArguments.0 -string /usr/bin/open "$agent"
plutil -insert ProgramArguments.1 -string -W "$agent"
plutil -insert ProgramArguments.2 -string "$app" "$agent"
plutil -insert RunAtLoad -bool true "$agent"
plutil -insert LimitLoadToSessionType -string Aqua "$agent"
plutil -insert StandardOutPath -string "$HOME/Library/Logs/CodexPetLimitRings.log" "$agent"
plutil -insert StandardErrorPath -string "$HOME/Library/Logs/CodexPetLimitRings.err.log" "$agent"
plutil -lint "$agent"
launchctl bootstrap "$gui" "$agent"
launchctl kickstart -k "$gui/com.codex-pet.limit-rings"
printf 'Rollback backup: %s\n' "$backup"
```

## Verify The Installation

```bash
set -euo pipefail

app="$HOME/Applications/CodexPetLimitRings.app"
plutil -extract CFBundleShortVersionString raw "$app/Contents/Info.plist"
plutil -extract CFBundleVersion raw "$app/Contents/Info.plist"
plutil -extract LSMinimumSystemVersion raw "$app/Contents/Info.plist"
vtool -show-build "$app/Contents/MacOS/CodexPetLimitRings"
codesign --verify --deep --strict "$app"
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
"$app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

Confirm version/build `1.0.16 / 25` and minimum macOS `15.0`. Confirm that the diagnostic remains privacy-safe, app-server is ready or has an explained bounded fallback, notifications have the expected state, and the rings are aligned to the live pet.

## Roll Back

Keep the failed build separate. Restore the prior app, LaunchAgent, preferences, and Skill from the backup directory printed during installation, then verify the restored version, LaunchAgent, pet alignment, and privacy-safe diagnostic again.

Follow [Rollback](rollback.md) for the complete restoration contract and validation checklist.
