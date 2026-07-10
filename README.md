# codex-pet-limit-rings

Codex pets are tiny ambient companions for the work happening in Codex. This project adds one more layer to that idea: your pet can quietly show how much Codex capacity you have left, without turning the app into a dashboard.

The experience is a small macOS companion app. It watches where the Codex pet is, draws two polished rings around it, and keeps those rings attached to the pet as it moves. It does not patch Codex, change pet art, or modify the Codex app bundle.

It works with whatever Codex pet you like. Built-in pet, custom pet, tiny dog, robot, weather daemon, or anything else: the app does not care. It only follows the pet window that Codex is already showing.

![Codex Pet Limit Rings around a Codex pet](docs/assets/codex-pet-limit-rings-screenshot.png)

## What You See

The rings are designed to be glanceable:

- The outer ring shows the short-window limit remaining.
- The inner ring shows the weekly limit remaining.
- Color moves from calm green/blue to amber and red as capacity gets low.
- Hovering over the pet or rings shows the exact percentages at the current ring endpoints.
- A small menu-bar icon exposes all available limit buckets, credits, monthly spend controls, reset credits, and limit status without modifying the account.
- A Daily Usage submenu shows the latest 14 account-usage days as text-labelled bars and refreshes every 15 minutes without storing usage history.
- Optional 25%, 10%, and recovery notifications are off by default and request macOS permission only when enabled.
- Reduced Motion, Increase Contrast, Differentiate Without Color, English, and Japanese are supported.

When the Codex pet is closed, the rings disappear. When the pet comes back, they come back too. On multi-display setups, the rings stay with the pet instead of jumping to whichever screen is focused.

Because the rings are drawn in a separate transparent overlay, they do not need pet-specific sprites, masks, metadata, or configuration. Change pets in Codex and the rings follow the new one automatically.

## Driedsandwich Compatibility Line

The downstream line keeps the original companion-app design and MIT license while focusing on compatibility with current ChatGPT/Codex desktop builds. It adds official app-server rate-limit reads, privacy-safe diagnostics, bounded fallback behavior, regression tests, and a shared local/CI release gate.

The published v0.5.1 release sets an explicit macOS 15.0 deployment target for both source builds and the downloadable app. It supersedes the v0.5.0 binary, which remains available for provenance but requires macOS 26.

The published v0.6.0 release adds read-only limit intelligence, opt-in notifications, accessibility-aware rendering, and English/Japanese UI. It deliberately does not consume reset credits, read daily account usage, or collect per-thread usage.

The unreleased v0.7.0 candidate adds memory-only Daily Usage Insights through stable app-server `account/usage/read`. It does not collect per-thread usage, inspect transcripts, store usage history, or mutate the account.

The upstream baseline and the split between upstream-compatible and downstream-only work are recorded in [docs/downstream-scope.md](docs/downstream-scope.md).

Publication provenance and current release status are recorded in [PUBLICATION_RECORD.md](PUBLICATION_RECORD.md).

## Why It Works This Way

The important design choice is the companion boundary. A menu item inside Codex itself would mean patching Electron app files and redoing that patch after app updates. That is brittle and hard to open source.

`codex-pet-limit-rings` stays outside the Codex app. It reads local pet-position state, asks the bundled Codex app-server for rate limits, and renders its own transparent always-on-top window around the pet. The result is reversible, inspectable, and easy for another Codex agent to install or modify without copying ChatGPT credentials.

Pet wakeups are handled by a lightweight filesystem watcher on Codex's local global-state file, with a slow fallback timer as a safety net. That lets the rings snap back when the pet is re-enabled without constantly polling for position changes.

## Quick Start

### Install The Published v0.6.0 App

The published v0.6.0 app supports macOS 15 and later on Apple silicon. The same source and package gates run on macOS 15 and macOS 26.

Download the app and checksum from the [v0.6.0 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.6.0), then verify the ZIP before opening it. The expected ZIP SHA-256 is `3230a6e83a02703bdc51f24737c5275d83baebd971abf84b7bde42ebf54764d1`.

```bash
version=0.6.0
expected_sha=3230a6e83a02703bdc51f24737c5275d83baebd971abf84b7bde42ebf54764d1
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

Back up an existing installation, stop its LaunchAgent, and replace it with the verified app:

```bash
version=0.6.0
release_dir="${release_dir:-$HOME/Downloads/CodexPetLimitRings-v$version}"
backup="$HOME/Library/Application Support/CodexPetLimitRings/Backups/$(date +%Y%m%d-%H%M%S)"
app="$HOME/Applications/CodexPetLimitRings.app"
agent="$HOME/Library/LaunchAgents/com.codex-pet.limit-rings.plist"
gui="gui/$(id -u)"

mkdir -p "$backup" "$HOME/Applications"
if [[ -f "$agent" ]]; then
  cp -a "$agent" "$backup/com.codex-pet.limit-rings.plist"
fi
launchctl bootout "$gui" "$agent" >/dev/null 2>&1 || true
pkill -TERM -f 'CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings' >/dev/null 2>&1 || true
if [[ -d "$app" ]]; then
  mv "$app" "$backup/CodexPetLimitRings.app"
fi
ditto "$release_dir/CodexPetLimitRings.app" "$app"
if [[ -f "$agent" ]]; then
  launchctl bootstrap "$gui" "$agent"
  launchctl kickstart -k "$gui/com.codex-pet.limit-rings"
else
  open "$app"
fi
printf 'Rollback backup: %s\n' "$backup"
```

Verify the installed version and privacy-safe runtime diagnostics:

```bash
plutil -extract CFBundleShortVersionString raw \
  "$HOME/Applications/CodexPetLimitRings.app/Contents/Info.plist"
plutil -extract LSMinimumSystemVersion raw \
  "$HOME/Applications/CodexPetLimitRings.app/Contents/Info.plist"
vtool -show-build \
  "$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings"
"$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

The release bundle is ad-hoc signed and not notarized. If macOS blocks the first launch, inspect the downloaded file and approve it from System Settings only after its SHA-256 and code signature pass the checks above. To restore the prior app and LaunchAgent, follow [docs/rollback.md](docs/rollback.md) using the backup directory printed by the commands above.

### Install From Source With Launch At Login

Clone this repository, then install the rings and LaunchAgent from source:

```bash
tools/install-limit-rings.sh
```

You should see a small rings icon in the macOS menu bar. Use that menu to inspect limit details, toggle rings, opt in to local notifications, refresh data, or quit. Notifications remain off until you enable them.

Then use any Codex pet normally. No pet setup step is required.

Run a development build without installing the login item:

```bash
tools/run-limit-rings.sh
```

Uninstall everything the installer adds:

```bash
tools/uninstall-limit-rings.sh
```

## Give This Repo To Codex

This repository is structured so a Codex agent can pick it up from a GitHub link.

Ask the agent:

```text
Use the bundled codex-pet-limit-rings skill from this repository. Install the rings companion for my Codex pet, verify the LaunchAgent is running, and confirm the rings stay anchored to the pet.
```

The agent should read:

- `AGENTS.md` for the project contract.
- `skills/codex-pet-limit-rings/SKILL.md` for the install, debug, and validation workflow.
- `docs/limit-rings.md` for the data and rendering model.

To install the bundled skill into local Codex:

```bash
tools/install-codex-skill.sh
```

## Data And Privacy

The app asks the Codex app-server for rate limits, then uses local Codex files only as support or fallback:

- The bundled or installed `codex app-server --stdio` provides the stable `account/rateLimits/read` protocol surface.
- `~/.codex/.codex-global-state.json` tells it whether the pet is open and where it is.
- The newest available `~/.codex/sqlite/logs_2.sqlite` or legacy `~/.codex/logs_2.sqlite` is used as a local fallback if app-server is unavailable.

It does not read `~/.codex/auth.json`, copy ChatGPT bearer tokens, or call the undocumented `backend-api/wham/usage` endpoint. It does not require an OpenAI API key and does not send pet images, screenshots, prompts, or repo contents anywhere.

If app-server fails briefly, the last successful snapshot remains available for up to 30 minutes while its reset window is still current. The menu labels the active source as `App Server`, `Cached`, or `Local` and reports `No current Codex limit data` instead of presenting expired values.

Run a privacy-safe compatibility check without printing tokens or user paths:

```bash
~/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings --diagnose
```

## Project Shape

```text
tools/
  codex-pet-limit-rings.swift      native macOS companion app
  install-limit-rings.sh           build, install, and start at login
  uninstall-limit-rings.sh         remove the app and login item
  run-limit-rings.sh               development launch
  build-limit-rings.sh             app bundle builder
  install-codex-skill.sh           copy the bundled skill into ~/.codex/skills
  test-limit-rings.sh              compile and run regression tests
  verify-release.sh                run the local and CI release gate
  package-release.sh               build a checked macOS arm64 release ZIP
  smoke-release-artifact.sh        download and inspect a published release ZIP

skills/codex-pet-limit-rings/
  SKILL.md                         Codex-agent workflow for this project

docs/
  downstream-scope.md                upstream baseline and downstream boundary
  limit-rings.md                   implementation contract and data flow
  rollback.md                      backup and rollback procedure
  release-checklist.md             publication evidence checklist

experiments/weather-pets/
  earlier weather-pet renderer     kept as a separate experiment
```

## Development

Build the app:

```bash
tools/build-limit-rings.sh
```

Render a static preview PNG:

```bash
deployment_target="$(plutil -extract LSMinimumSystemVersion raw tools/CodexPetLimitRings-Info.plist)"
swiftc -parse-as-library -target "arm64-apple-macosx$deployment_target" tools/codex-pet-limit-rings.swift -o tmp/codex-pet-limit-rings -framework AppKit -lsqlite3
tmp/codex-pet-limit-rings --preview tmp/limit-rings-preview.png --size 164
```

Run the compatibility and cache regression tests:

```bash
tools/test-limit-rings.sh
```

Validate the shell scripts:

```bash
bash -n tools/*.sh
```

Run the complete local/CI release gate:

```bash
tools/verify-release.sh
```

Build an ad-hoc-signed macOS arm64 ZIP and SHA-256 file under ignored `dist/`:

```bash
tools/package-release.sh
```

Smoke-test the published release without replacing the installed app:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.6.0
```

On an older macOS host, perform checksum, signature, architecture, version, and deployment-target inspection without launching the binary:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.6.0 --inspect-only
```

## Experiments

The original exploration included a Python renderer for weather-mutated Codex pets. That work now lives under `experiments/weather-pets/` so the public repo can stay focused on limit rings while preserving the larger idea: Codex pets can become ambient interfaces for state, context, and mood.

## License

MIT. See `LICENSE`.
