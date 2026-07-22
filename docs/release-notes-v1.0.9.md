# Codex Pet Limit Rings 1.0.9

Version 1.0.9 recovers stale usage-limit refreshes after a limit reset or an app-server initialization failure, while preserving the existing read-only and memory-only boundaries.

## Highlights

- Makes **Refresh Now** reuse a healthy connection but immediately replace a disconnected, stale, timed-out, or initialization-stalled app-server connection.
- Keeps one coalesced full rate-limit read in flight with the existing five-second timeout.
- Invalidates callbacks from older connection generations so stale responses cannot overwrite a recovered snapshot.
- Escalates an overdue 120-second full-snapshot watchdog request to a fresh connection while retaining bounded reconnect backoff.
- Marks overdue app-server values as **Stale** in the rings and Connection Health using localized, non-color indicators.

## Privacy And Scope

- Uses only the existing read-only rate-limit and usage methods.
- Adds no reset consumption, account mutation, thread API, persistent diagnostic log, IPC, permission, or notification type.
- Keeps connection state, safe timeout reasons, and recovery paths in memory only.
- Stale values cannot trigger limit notifications.

## Verification

- Main CI run [`29894494890`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29894494890) passed the verifier, package checks, and published v1.0.0 artifact smoke test on macOS 15 and macOS 26.
- The published artifact passed checksum verification, local-path sanitization, ad-hoc signature verification, arm64 and macOS 15.0 inspection, English/Japanese resource checks, preview execution, and privacy-safe diagnostics.
- Unit tests cover initialization-stall recovery, reset and rollover refreshes, single in-flight coalescing, timeout and generation invalidation, sparse/full races, stale presentation, notification deduplication, and English/Japanese parity.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `a69411f78cfefa77d0ed955524fbb829dbbe3f5f`.
- ZIP SHA-256: `e085c5ee47e9a8ebafbc8cb6d2788d673b26c85ab1b520792bbe5da8b42aa273`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.9` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.9), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up v1.0.8 app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
