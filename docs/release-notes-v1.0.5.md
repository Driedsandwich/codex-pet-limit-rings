# Codex Pet Limit Rings 1.0.5 Candidate

Version 1.0.5 is a maintenance candidate that makes the existing 120-second full rate-limit refresh resilient to a stalled or missed main-run-loop timer.

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

## Verification Before Release

- Run all unit tests, including early and missed ticks, continuous sparse notifications, sleep/wake time jumps, timeout cancellation, bounded reconnect, and manual/scheduled coalescing.
- Pass build, privacy scan, packaging, local artifact checks, and the published v1.0.0 baseline smoke test on macOS 15 and macOS 26.
- Soak the installed candidate for more than 120 seconds and confirm a scheduled full sync updates its in-memory success time without user interaction.

## Rollback

- Keep the installed v1.0.4 app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
