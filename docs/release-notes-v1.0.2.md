# Codex Pet Limit Rings 1.0.2

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

## Verification

- Unit coverage includes continuous sparse notifications, the absolute 120-second deadline, window rollover metadata replacement, manual/scheduled coalescing, five-second timeout invalidation, bounded reconnect backoff, sparse/full races, unknown fields, notification deduplication, and English/Japanese resource parity.
- Main CI run 29184418110 passed build, all unit tests, privacy scan, package verification, and the published v1.0.0 artifact smoke test on macOS 15 and macOS 26.
- The published v1.0.2 package passed checksum, ad-hoc signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release: [`v1.0.2`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.2).
- Release target: `d88eabb77b7265928c74b9d51b69e5739bb632a8`.
- ZIP SHA-256: `46b0b8eda6ce48fbb46192f321edab4580571cd309f2ec09769482e942238e93`.
- Published artifact smoke test passed checksum, signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.
