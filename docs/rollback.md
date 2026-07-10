# Rollback

Use this procedure when a newly installed Codex Pet Limit Rings build fails its runtime checks.

## Before Updating

Back up the installed app and LaunchAgent without changing their contents:

```bash
backup="$HOME/Library/Application Support/CodexPetLimitRings/Backups/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
cp -a "$HOME/Applications/CodexPetLimitRings.app" "$backup/CodexPetLimitRings.app"
cp -a "$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist" "$backup/com.codex-pet.limit-rings.plist"
```

Record the generated backup directory before continuing.

## Restore A Backup

Set `backup` to the directory recorded above, unload the current LaunchAgent, restore both artifacts, and start it again:

```bash
launchctl bootout "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist" >/dev/null 2>&1 || true
pkill -TERM -f 'CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings' >/dev/null 2>&1 || true
cp -a "$backup/CodexPetLimitRings.app" "$HOME/Applications/CodexPetLimitRings.app"
cp -a "$backup/com.codex-pet.limit-rings.plist" "$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
launchctl kickstart -k "gui/$(id -u)/com.codex-pet.limit-rings"
```

## Verify The Restore

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
"$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

Do not delete the failed build or backup as part of rollback. Cleanup is a separate decision after the restored version is verified.
