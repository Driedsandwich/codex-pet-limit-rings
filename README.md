# codex-pet-limit-rings

Codex pets are tiny ambient companions for work in the ChatGPT desktop app. This project adds one more layer to that idea: your pet can quietly show how much Codex capacity you have left, without turning ChatGPT into a dashboard.

The experience is a small macOS companion app. It watches where ChatGPT's Codex pet is, draws the available polished limit rings around it, and keeps those rings attached to the pet as it moves. It does not patch ChatGPT, change pet art, or modify the ChatGPT app bundle.

It works with whatever Codex pet you like. Built-in pet, custom pet, tiny dog, robot, weather daemon, or anything else: the app does not care. It only follows the pet window that ChatGPT is already showing.

![Codex Pet Limit Rings around a Codex pet](docs/assets/codex-pet-limit-rings-screenshot.png)

_Example with both the optional short-window limit and the weekly limit available; when ChatGPT reports only the weekly limit, the app shows one correctly identified ring._

## What You See

The rings are designed to be glanceable:

- The outer ring shows the short-window limit remaining when Codex reports one.
- The inner ring shows the weekly limit remaining; when only the weekly window is reported, it remains correctly identified even if Codex places it in the `primary` field.
- Color moves from calm green/blue to amber and red as capacity gets low.
- Hovering over the pet or rings shows the exact percentages at the current ring endpoints.
- Changing the pet-size slider resizes and recenters the rings with the live pet.
- A small menu-bar icon exposes all available limit buckets, credits, monthly spend controls, reset credits, and limit status without modifying the account.
- A Daily Usage submenu shows the latest 14 account-usage days plus current and longest streaks, longest turn, peak day, and lifetime totals, refreshing every 15 minutes without storing usage history.
- A Connection Health submenu shows the Codex CLI version, live/cached/local/reconnecting state, rate-limit and usage freshness, the last live/full/value-change cadence, and privacy-safe failure reasons using text and symbols rather than color alone.
- Optional 25%, 10%, and recovery notifications are off by default and request macOS permission only when enabled.
- Reduced Motion, Increase Contrast, Differentiate Without Color, English, and Japanese are supported.

When ChatGPT exits or the pet is closed, minimized, or moved off the active Space, the rings disappear instead of remaining at stale saved coordinates. When the live pet window comes back, they come back too. On multi-display setups, the rings stay with the pet instead of jumping to whichever screen is focused.

Because the rings are drawn in a separate transparent overlay, they do not need pet-specific sprites, masks, metadata, or configuration. Change pets in Codex and the rings follow the new one automatically.

## Quick Start

The published v1.0.10 app supports macOS 15 and later on Apple silicon. Download the app and checksum from the [v1.0.10 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.10), verify the ZIP SHA-256 against `ad4c87912b085695eeda10bba6e911b235e1077d11059d6002fb6d1838a0d3df`, then open the verified app.

If you are replacing an existing installation or want the complete checksum, backup, LaunchAgent, diagnostic, and rollback procedure, use [Verified Installation And Rollback](#verified-installation-and-rollback). To build and install from source with launch at login, run:

```bash
tools/install-limit-rings.sh
```

No pet-specific setup is required. Notifications remain off until you explicitly enable them from the menu-bar icon.

## Driedsandwich Compatibility Line

This fork keeps the original companion-app design and MIT license, then extends it for current ChatGPT/Codex desktop builds. The main differences from upstream are:

| Area | Upstream foundation | This fork (current source) |
| --- | --- | --- |
| Desktop compatibility | External overlay that follows the Codex pet | Current ChatGPT/Codex window matching, multi-display tracking, long-lived app-server updates, bounded reconnect/fallback, and a persistent monotonic full-snapshot watchdog that sparse events cannot postpone |
| Limit information | Two glanceable remaining-capacity rings | All available limit buckets, credits, monthly caps, limit reasons, reset-credit counts, reset metadata freshness, and privacy-safe connection health; all account access remains read-only |
| Usage and alerts | Ring visualization | Memory-only 14-day account usage and aggregate milestones, plus optional 25%, 10%, and recovery notifications that remain off until enabled |
| Accessibility and language | Visual ring status | Reduced Motion, Increase Contrast, Differentiate Without Color, text/symbol status cues, and English/Japanese UI |
| Distribution and verification | Source-based companion app | macOS 15+ Apple-silicon ZIP releases, checksum and rollback instructions, privacy diagnostics, macOS 15/26 CI, regression tests, packaging checks, and published-artifact smoke tests |

The privacy boundary is intentionally narrow: no ChatGPT credential copying, account mutation, reset-credit consumption, thread/turn APIs, transcript inspection, or persistent usage history.

<details>
<summary>Release-by-release history</summary>

<br>

- v0.5.1 established the current macOS 15.0 deployment baseline.
- v0.6.0 through v0.9.0 added read-only limit details, opt-in notifications, accessibility and localization, memory-only usage summaries, live updates, and connection health.
- v1.0.0 through v1.0.3 strengthened compatibility, freshness, full-snapshot reconciliation, and optional short-window handling.
- v1.0.4 through v1.0.8 hardened pet lifecycle, current ChatGPT surface and size tracking, release path privacy, watchdog recovery, and in-place app relaunch recovery.
- v1.0.9 recovers stale refreshes after a reset, timeout, disconnection, or app-server initialization stall without expanding the read-only or memory-only boundary.
- v1.0.10 strengthens runtime fallback trust, LaunchServices startup, menu lifecycle safety, package verification, installation safety, and complete rollback.

See [CHANGELOG.md](CHANGELOG.md) for the complete release-by-release history.

</details>

The upstream baseline and the split between upstream-compatible and downstream-only work are recorded in [docs/downstream-scope.md](docs/downstream-scope.md).

Publication provenance and current release status are recorded in [PUBLICATION_RECORD.md](PUBLICATION_RECORD.md).

The reliability-first product boundary and change triggers are recorded in [docs/maintenance-strategy.md](docs/maintenance-strategy.md).

## Why It Works This Way

The important design choice is the companion boundary. A menu item inside Codex itself would mean patching Electron app files and redoing that patch after app updates. That is brittle and hard to open source.

`codex-pet-limit-rings` stays outside the ChatGPT desktop app. It reads local pet-position hints, asks the bundled Codex app-server for rate limits, and renders its own transparent always-on-top window around the pet. The result is reversible, inspectable, and easy for another Codex agent to install or modify without copying ChatGPT credentials.

Pet wakeups are handled by a lightweight filesystem watcher on Codex's local global-state file, official ChatGPT application lifecycle events, and a persistent two-second dispatch watchdog for missed events. That lets the rings snap back when the pet is re-enabled or ChatGPT relaunches without depending on a main-run-loop timer.

## Verified Installation And Rollback

### Install The Published v1.0.10 App

The published v1.0.10 app supports macOS 15 and later on Apple silicon. The verified source and package gates pass on macOS 15 and macOS 26, and the published artifact passed the public smoke test.

Download the app and checksum from the [v1.0.10 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.10), then verify the ZIP before opening it. The expected ZIP SHA-256 is `ad4c87912b085695eeda10bba6e911b235e1077d11059d6002fb6d1838a0d3df`.

```bash
set -euo pipefail

version=1.0.10
expected_sha=ad4c87912b085695eeda10bba6e911b235e1077d11059d6002fb6d1838a0d3df
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
set -euo pipefail

version=1.0.10
release_dir="${release_dir:-$HOME/Downloads/CodexPetLimitRings-v$version}"
backup="$HOME/Library/Application Support/CodexPetLimitRings/Backups/$(date +%Y%m%d-%H%M%S)"
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
set -euo pipefail

plutil -extract CFBundleShortVersionString raw \
  "$HOME/Applications/CodexPetLimitRings.app/Contents/Info.plist"
plutil -extract LSMinimumSystemVersion raw \
  "$HOME/Applications/CodexPetLimitRings.app/Contents/Info.plist"
vtool -show-build \
  "$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings"
"$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

The release bundle is ad-hoc signed and not notarized. If macOS blocks the first launch, inspect the downloaded file and approve it from System Settings only after its SHA-256 and code signature pass the checks above. To restore the prior app, LaunchAgent, preferences, and Skill, follow [docs/rollback.md](docs/rollback.md) using the backup directory printed by the commands above.

### Install From Source With Launch At Login

Clone this repository, then install the rings and LaunchAgent from source:

```bash
tools/install-limit-rings.sh
```

The LaunchAgent waits on `/usr/bin/open -W` so LaunchServices owns the GUI-app
lifecycle. It does not execute the inner app binary directly from launchd,
which can prevent the long-lived app-server response handler from receiving
initialization output on current macOS and ChatGPT builds.

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

The app uses a local stdio connection to the Codex app-server currently bundled with the ChatGPT desktop app, then uses local Codex files only as support or fallback. OpenAI documents [`codex app-server`](https://learn.chatgpt.com/docs/developer-commands?surface=cli#cli-codex-app-server) as experimental and subject to change, so this project treats compatibility as a tested current contract rather than a permanent API guarantee:

- `account/rateLimits/read` provides full rate-limit snapshots, while sparse `account/rateLimits/updated` notifications keep available values current between full reads.
- `account/usage/read` refreshes the memory-only 14-day usage view every 15 minutes.
- `~/.codex/.codex-global-state.json` provides saved open-state and geometry hints, but those values alone never make the rings visible. A matching live, on-screen ChatGPT pet surface is required.
- `CGWindowListCopyWindowInfo` supplies the live pet window's owner, layer, and geometry metadata. The app does not capture window pixels or request Screen Recording or Accessibility permission.
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
  verify-release-artifact.sh       apply the shared ZIP and app artifact gates
  smoke-release-artifact.sh        download and inspect a published release ZIP

skills/codex-pet-limit-rings/
  SKILL.md                         Codex-agent workflow for this project

docs/
  downstream-scope.md                upstream baseline and downstream boundary
  limit-rings.md                   implementation contract and data flow
  maintenance-strategy.md           product boundary and update triggers
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
swiftc -parse-as-library -target "arm64-apple-macosx$deployment_target" tools/codex-pet-limit-rings.swift -o tmp/codex-pet-limit-rings -framework AppKit -framework UserNotifications -lsqlite3
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

CI intentionally smoke-tests v1.0.0 as the long-term published compatibility baseline, including its pinned digest and compatibility checks, while building and testing the current source. Because that artifact predates the v1.0.4 build-path sanitization gate, only its local absolute-path scan has an explicit version-specific legacy exception; later artifacts do not inherit that exception. The manual smoke commands below target the latest published v1.0.10 artifact and require every current gate without replacing the installed app:

```bash
EXPECTED_MIN_OS=15.0 \
EXPECTED_SHA256=ad4c87912b085695eeda10bba6e911b235e1077d11059d6002fb6d1838a0d3df \
  tools/smoke-release-artifact.sh 1.0.10
```

On an older macOS host, perform checksum, signature, architecture, version, and deployment-target inspection without launching the binary:

```bash
EXPECTED_MIN_OS=15.0 \
EXPECTED_SHA256=ad4c87912b085695eeda10bba6e911b235e1077d11059d6002fb6d1838a0d3df \
  tools/smoke-release-artifact.sh 1.0.10 --inspect-only
```

## Experiments

The original exploration included a Python renderer for weather-mutated Codex pets. That work now lives under `experiments/weather-pets/` so the public repo can stay focused on limit rings while preserving the larger idea: Codex pets can become ambient interfaces for state, context, and mood.

## License

MIT. See `LICENSE`.
