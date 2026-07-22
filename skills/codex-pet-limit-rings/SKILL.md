---
name: codex-pet-limit-rings
description: Install, run, customize, package, or debug the Codex Pet Limit Rings macOS companion app for Codex pets. Use when the user asks for Codex pet usage-limit rings, a menu-bar toggle, launch-at-login packaging, live/cached Codex limit visualization, or open-source distribution of the rings overlay.
---

# Codex Pet Limit Rings

## Core Rule

Keep the Codex desktop app unpatched by default. Ship and modify the rings as a companion macOS app that reads local Codex state and exposes its own menu-bar icon. Only discuss direct Codex app menu patching as a brittle optional route, because it requires `app.asar` patching, Electron integrity updates, and re-signing after Codex updates.

The rings are pet-agnostic. Do not add pet-specific setup unless a user explicitly asks for a custom visual treatment; by default the overlay follows whatever Codex pet is currently active.

## Locate The Project

If this skill is bundled in the repository, the project root is two directories above this `SKILL.md`. Otherwise find or ask for a checkout containing:

```text
tools/codex-pet-limit-rings.swift
tools/install-limit-rings.sh
tools/run-limit-rings.sh
```

Use that checkout as the working directory. Read `AGENTS.md` first if it exists.

## Common Tasks

Install or enable the rings for a user:

```bash
tools/install-limit-rings.sh
```

Run a development build without installing a login item:

```bash
tools/run-limit-rings.sh
```

Uninstall:

```bash
tools/uninstall-limit-rings.sh
```

Install this skill into local Codex:

```bash
tools/install-codex-skill.sh
```

Verify the live app:

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
```

## Data Contract

The rings read:

OpenAI documents `codex app-server` as experimental and subject to change without notice. Treat the methods below as the currently tested compatibility contract, not as permanently stable APIs.

- One long-lived `codex app-server --stdio` connection using `account/rateLimits/read` plus sparse `account/rateLimits/updated` notifications for primary usage-limit data. A persistent monotonic watchdog reconciles 120 seconds after the last successful full snapshot; sparse notifications must not postpone that deadline. One five-second full read is allowed, sparse updates received in flight must be reapplied afterward, and an unresolved overdue read must invalidate the old connection generation before recreating the connection through bounded backoff. `Refresh Now` reuses a healthy, current connection, but immediately creates a fresh connection while disconnected, stale, or already waiting on a full read.
- The `account/usage/read` method every 15 minutes for a memory-only, last-14-days daily usage view.
- `~/.codex/.codex-global-state.json` for `electron-avatar-overlay-open`, saved pet coordinates, and legacy `electron-avatar-overlay-bounds.mascot` metadata when present. Current ChatGPT builds may omit the top-level mascot size.
- The newest existing `~/.codex/sqlite/logs_2.sqlite` or legacy `~/.codex/logs_2.sqlite` for fallback to the newest current `codex.rate_limits` event when app-server fails.

The app must not read `auth.json` or call the undocumented `backend-api/wham/usage` endpoint. The outer ring is the short-window remaining percentage. The inner ring is the weekly remaining percentage. The menu summary distinguishes `App Server`, `Cached`, and `Local` sources and must not show expired values as current. Sparse notifications must preserve nullable metadata from the latest full snapshot. The details submenu may show multiple limit buckets, credits, monthly spend control, reached reasons, and reset-credit availability, but must never consume a reset credit or mutate the account.

Notifications are local, off by default, and request permission only after the user enables them. Cached, stale, or SQLite fallback values must not trigger notifications. Daily usage, aggregate milestones, live/full/value-change cadence observations, the last safe connection failure, and the manual refresh path must not be written to preferences, SQLite, JSONL, or another durable store. Connection health may use only the selected CLI's bounded version output, existing in-memory connection flag, fallback source, safe failure category, refresh path, and rate-limit/usage observation times. Full-snapshot metadata freshness must remain distinct from sparse live-value freshness, and overdue full metadata must be labelled stale rather than live in both the ring and Connection Health using a non-color marker. Do not expose CLI paths or raw process output. Do not subscribe to `thread/tokenUsage/updated`, resume or fork threads, or retain thread or turn identifiers.

Honor Reduced Motion, Increase Contrast, and Differentiate Without Color. Keep English and Japanese localization resources in the app bundle.

Run `CodexPetLimitRings --diagnose` for a privacy-safe JSON compatibility check. It must not print tokens, raw account identifiers, or user-specific paths.

Pet wakeups, size changes, and moves are driven by a filesystem watcher on `~/.codex/.codex-global-state.json`, official `com.openai.codex` application lifecycle notifications, and a persistent two-second dispatch watchdog for missed events. The fallback must not depend on a main-run-loop `Timer`, so an in-place ChatGPT update that replaces the process can hide stale rings and rediscover the new pet window without restarting the companion app. A matching on-screen Codex pet overlay is required before displaying rings; persisted open state and bounds are only a positioning reference. Legacy builds use the saved overlay geometry. Current builds that omit top-level mascot dimensions must use the exact on-screen `Codex Pet Mascot Effect` window owned by the running `com.openai.codex` process. Derive the current mascot size from that live effect center and the current saved mascot origin; use historical size only when live geometry is missing or impossible so the full pet-size slider range can resize the rings. If macOS redacts that window name, require the official process, on-screen pet-effect layer, and bounded pet-relative geometry that still admits the maximum slider effect surface, without requesting a new permission. Do not treat generic `ChatGPT`, third-party wrapper, or Stage Manager windows as pet evidence. Hide the rings when Codex exits, the pet closes, or its overlay is minimized or on another Space, and restore them when the live overlay returns. Keep that live-window gate, event-driven path, size tracking, and drag mismatch protection intact when changing frame-following behavior.

## Editing Workflow

When changing behavior or visuals:

1. Edit `tools/codex-pet-limit-rings.swift`.
2. Keep packaging scripts in `tools/` and update `docs/limit-rings.md` when the user-facing contract changes.
3. Run:

```bash
bash -n tools/*.sh
deployment_target="$(plutil -extract LSMinimumSystemVersion raw tools/CodexPetLimitRings-Info.plist)"
swiftc -parse-as-library -target "arm64-apple-macosx$deployment_target" tools/codex-pet-limit-rings.swift -o tmp/codex-pet-limit-rings -framework AppKit -framework UserNotifications -lsqlite3
tools/test-limit-rings.sh
tools/verify-release.sh
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 1.0.0
tmp/codex-pet-limit-rings --preview tmp/limit-rings-preview.png --size 164
```

4. Relaunch with `tools/run-limit-rings.sh` for development or `tools/install-limit-rings.sh` for the packaged login-item flow.

## Open-Source Hygiene

Keep the app privacy-preserving, source-buildable, and uninstallable. Do not commit local `tmp/` builds, logs, derived pet spritesheets, or user-specific Codex data. Preserve the MIT license and document any new local files or permissions in `docs/limit-rings.md`.
