# Codex Pet Limit Rings 1.0.5

Version 1.0.5 makes the existing 120-second full rate-limit refresh resilient to a stalled or missed main-run-loop timer.

## Highlights

- Replaces the one-shot reconcile timer with a persistent monotonic watchdog on a dedicated queue.
- Keeps sparse live notifications immediate without allowing them to postpone full reset-metadata refreshes.
- Reuses the single in-flight request gate, five-second timeout, manual coalescing, sparse/full merge, and bounded app-server reconnect.
- Marks overdue full metadata as stale rather than live and shows its last success time and acquisition path in English and Japanese.

## Privacy And Scope

- Uses only stable read-only `account/rateLimits/read` and existing `account/rateLimits/updated` notifications.
- Keeps all cadence and freshness observations in memory only.
- Adds no credential read, persistent log, IPC, permission, notification type, thread API, experimental API, reset consumption, or account mutation.
- Stale app-server metadata does not trigger limit notifications.

## Verification

- Main CI run [`29374761072`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29374761072) passed build, all unit tests, privacy scan, package verification, and the published v1.0.0 baseline smoke test on macOS 15 and macOS 26.
- Unit tests cover early and missed ticks, continuous sparse notifications, sleep/wake time jumps, timeout cancellation, bounded reconnect, and manual/scheduled coalescing.
- The installed candidate completed a scheduled full sync after more than 120 seconds without user interaction, then passed reconnect, notification-off, ring-alignment, and privacy-safe diagnostic checks.
- The published artifact passed checksum, local-path sanitization, ad-hoc signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `84e8daab1fae9182708067c348d94d8d877cb985`.
- ZIP SHA-256: `eaaa32c870542990429fe2586224c225795f87ebd9ab39259ba8c4c60740e7bb`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.5` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.5), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
