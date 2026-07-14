# Codex Pet Limit Rings

Codex Pet Limit Rings is a native macOS companion app for Codex pets. It does not patch Codex, replace pet art, or modify the Codex app bundle. It follows the current pet with a transparent always-on-top window and exposes its own menu-bar icon.

The rings are pet-agnostic. They work with any pet Codex displays because the app tracks the pet window bounds rather than reading, editing, or understanding the pet artwork.

## Experience Contract

- A rings icon appears in the macOS menu bar.
- `Show Rings` toggles the overlay without quitting the app.
- `Refresh Now` rereads usage and pet-position state.
- `Limit Details` lists every returned limit bucket plus read-only credit, monthly limit, reached-status, and reset-credit summaries.
- `Daily Usage` shows up to 14 recent daily token buckets plus current/longest streak, longest turn, peak day, and lifetime totals as localized text-labelled rows and refreshes every 15 minutes.
- `Connection Health` shows the sanitized Codex CLI version, explicit live/cached/local/reconnecting state, separate rate-limit and usage freshness, the last live/full/value-change cadence, and privacy-safe failure reasons.
- `Limit Notifications` is off by default. Enabling it is the only action that requests macOS notification permission.
- Hovering over the ring or pet shows exact remaining percentages at the arc endpoints.
- Dragging the pet makes the rings follow the gesture immediately while Codex persists the new position.
- Closing Codex or the pet hides the rings. A minimized pet or a pet on another Space also remains hidden until its live overlay is on screen again.
- Multi-display positioning uses the screen containing the pet bounds, not the currently focused screen.
- macOS desktop/Space switching hides the rings while the pet is off the active Space and restores them with the pet when its Space becomes active.
- Switching to another Codex pet requires no extra setup; the overlay follows the active pet.

## Data Flow

The app reads live usage first, then local files as support or fallback:

- One long-lived `codex app-server --stdio` connection is the primary source. It performs the required `initialize` / `initialized` handshake, reads stable `account/rateLimits/read`, and applies stable sparse `account/rateLimits/updated` notifications.
- The same connection reads stable `account/usage/read` every 15 minutes. Normalized daily buckets plus current/longest streak, longest turn, peak daily tokens, and lifetime tokens remain in memory only.
- `~/.codex/.codex-global-state.json`: saved pet bounds, using `electron-avatar-overlay-bounds.mascot`, as a reference for locating the live window rather than proof that the pet is visible.
- `electron-avatar-overlay-open` in the same state file: whether the Codex pet is currently open.
- The newest existing `~/.codex/sqlite/logs_2.sqlite` or legacy `~/.codex/logs_2.sqlite`: fallback source using the newest current `codex.rate_limits` event when app-server fails.

The app watches `~/.codex/.codex-global-state.json` with a macOS file event source, so pet open/close and position writes trigger an immediate frame update. Display still requires a matching live, on-screen Codex overlay window; stale `overlay-open` and bounds values cannot keep the rings visible after Codex exits. A two-second frame timer hides stale rings and restores them when the live pet returns if a state-file event is missed. App-server disconnects use bounded exponential reconnect delays; the 20-second local rate-limit poll runs only while disconnected.

While app-server is connected, sparse notifications remain the normal update path. A persistent watchdog runs outside the main run loop and uses monotonic continuous time to require a read-only `account/rateLimits/read` 120 seconds after the last successful full snapshot. Sparse notifications cannot postpone that deadline. Early or missed watchdog ticks are harmless: an early tick waits and a later overdue tick reissues the request. Manual and scheduled full reads share a single in-flight gate and a five-second timeout; a continued failure closes and recreates the app-server connection through bounded reconnect backoff. Sparse notifications received while a full read is pending are displayed immediately, buffered, and reapplied to the returned full snapshot so older full data cannot overwrite a newer live value. A full snapshot that omits the short-window bucket clears the old short ring and its notification history when no newer sparse update reports that bucket. A later sparse update or full snapshot restores the ring immediately. Connection Health keeps the latest live-notification, full-sync, and displayed-value-change times and origins in memory only. Once full-snapshot metadata passes its deadline, the source is labelled stale rather than live until a full read succeeds, and stale metadata cannot trigger limit notifications.

The live overlay window is matched to the `com.openai.codex` application bundle rather than a fixed visible process name. Saved bounds rank matching candidates and provide mascot offsets, but only an on-screen match authorizes drawing. This supports both older builds presented as `Codex` and current builds presented as `ChatGPT` without matching unrelated ChatGPT wrappers. During pet drags, the same match gate rejects distant windows while the existing predicted-frame path keeps the rings attached to the gesture.

No OpenAI API key is required. The app no longer reads ChatGPT bearer tokens from `auth.json`. The menu summary distinguishes `App Server`, a recent in-memory `Cached` snapshot, and the `Local` SQLite fallback. Expired values are rejected.

The full `account/rateLimits/read` snapshot is decoded read-only. The app can display `rateLimitsByLimitId`, credit availability and balance, individual monthly spend control, limit-reached reason, and the available reset-credit count. Main Codex windows are classified by their reported duration rather than assuming the `primary` field always means short-window usage, because a remaining weekly window may move into that field when the short window is absent. If Codex does not report a short window, the weekly and additional limits remain visible and the menu states that the short window was not reported. When Codex does report short-window usage, the menu separately states that enforcement status is not reported; the app does not infer an unlimited plan or permanent policy change. It never calls `account/rateLimitResetCredit/consume` and does not mutate the account.

Daily account usage has remained read-only since v0.7.0, is refreshed every 15 minutes, and is never persisted. Version 0.9.0 displays the stable response's aggregate current/longest streak, longest turn, peak-day, and lifetime fields. Version 1.0.0 adds only derived compatibility information: the bounded Codex CLI version, current source, separate in-memory observation times, freshness labels, and a small safe failure category. Version 1.0.1 adds bounded full-snapshot reconciliation and memory-only cadence observations. The published v1.0.2 release fixes that reconcile deadline so sparse notifications cannot postpone snapshot metadata refreshes, and labels full-snapshot freshness separately. The v1.0.5 candidate makes that deadline resilient to main-run-loop timer stalls and sleep/wake gaps with a monotonic watchdog. Per-thread usage remains excluded: the app does not subscribe to `thread/tokenUsage/updated`, resume or fork threads, inspect prompts, retain thread identifiers, or parse SQLite/JSONL for usage.

The app discovers Codex CLI installations from explicit environment overrides, the current `ChatGPT.app` bundle, older `Codex.app` bundles, Homebrew locations, and `PATH`. `--diagnose` reports compatibility state as JSON without emitting tokens or user-specific paths.

## Rendering Model

- Outer ring: short-window remaining percentage.
- Inner ring: weekly remaining percentage.
- Ring colors are derived from remaining capacity: green/blue for healthy, amber for low, red for critical.
- Exact percentages are shown only on hover to keep the pet feeling ambient rather than dashboard-like.
- Additional model-limit buckets may appear as small outer markers when available.
- Reduced Motion freezes pulse and glint animation. Increase Contrast strengthens tracks and readouts. Differentiate Without Color uses a dashed secondary ring and alternating marker shapes.
- Daily bars use filled and dotted text segments plus numeric token labels, so they do not depend on color or animation and inherit macOS contrast behavior.
- Connection and freshness states use distinct words and symbols (`●`, `↻`, `↙`, `✓`, `!`, `…`), remain static under Reduced Motion, and do not depend on color.

## Notifications And Localization

- Notifications are disabled by default and stored as an explicit local preference.
- Enabling notifications requests macOS alert permission once; disabling them clears threshold history.
- Fresh app-server values can notify when a limit crosses 25%, crosses 10%, or recovers above 25%.
- Repeated reads inside the same threshold band do not notify again. Cached and SQLite fallback values never trigger alerts.
- The app bundle includes English and Japanese menu and notification resources. macOS chooses the language from the user's preferred language order.

## Install Contract

`tools/install-limit-rings.sh` builds:

```text
~/Applications/CodexPetLimitRings.app
```

and installs:

```text
~/Library/LaunchAgents/com.codex-pet.limit-rings.plist
```

The LaunchAgent starts the app at login. The installer also removes the earlier prototype app and LaunchAgent names if present:

```text
~/Applications/CodexLimitAura.app
~/Library/LaunchAgents/com.codex-pet.limit-aura.plist
```

Before replacement, the installer saves any existing app, LaunchAgent, and available preferences under a timestamped directory in `~/Library/Application Support/CodexPetLimitRings/Backups/`. The skill installer similarly backs up an existing local skill under `~/.codex/backups/codex-pet-limit-rings/`.

`tools/uninstall-limit-rings.sh` unloads the LaunchAgent, removes the app bundle, clears the saved ring visibility preference, and also cleans up those earlier prototype names.

## Development

Build and run the app from the repository:

```bash
tools/run-limit-rings.sh
```

Render a static preview:

```bash
swiftc -parse-as-library tools/codex-pet-limit-rings.swift -o tmp/codex-pet-limit-rings -framework AppKit -framework UserNotifications -lsqlite3
tmp/codex-pet-limit-rings --preview tmp/limit-rings-preview.png --size 164
```

## Codex Skill

The repository includes a skill at `skills/codex-pet-limit-rings/`. Copy that folder into `~/.codex/skills/` or run `tools/install-codex-skill.sh` to make Codex auto-discover the workflow in future sessions.

The skill intentionally points agents at the companion-app boundary and validation commands. It should not encourage app-bundle patching as the default path.
