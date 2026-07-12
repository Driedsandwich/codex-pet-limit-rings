# Codex Pet Limit Rings 1.0.2 Candidate

Version 1.0.2 fixes the full-snapshot deadline used by the v1.0.1 live update cadence without expanding the app's data or permission boundary.

## Highlights

- Anchor the 120-second reconcile deadline to the last successful full rate-limit snapshot.
- Keep continuous sparse notifications from postponing reset-time and other snapshot-metadata refreshes.
- Preserve one five-second in-flight full read, manual/scheduled coalescing, buffered sparse reapplication, and the existing reconnect backoff capped at 30 seconds.
- Show full-snapshot metadata time, path, and current/stale state separately in Connection Health.

## Privacy And Scope

- Uses only stable `account/rateLimits/read` and `account/rateLimits/updated` plus existing in-memory connection state.
- Deadline and freshness observations remain memory-only and disappear when the app exits.
- Adds no persistent diagnostics, IPC, permission, notification type, account mutation, thread API, or experimental API method.
- Existing notification thresholds remain opt-in, default to off, and suppress duplicate notifications.

## Verification Plan

- Unit coverage includes continuous sparse notifications, the absolute 120-second deadline, window rollover metadata replacement, manual/scheduled coalescing, five-second timeout invalidation, bounded reconnect backoff, sparse/full races, unknown fields, notification deduplication, and English/Japanese resource parity.
- The candidate must pass build, all unit tests, privacy scan, package verification, and the published v1.0.0 artifact smoke test on macOS 15 and macOS 26.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Tag and Release are not created during the candidate phase.
