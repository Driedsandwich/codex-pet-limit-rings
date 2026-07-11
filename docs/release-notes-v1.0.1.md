# Codex Pet Limit Rings 1.0.1

Version 1.0.1 improves the cadence of live rate-limit updates without expanding the app's data or permission boundary.

## Highlights

- Keep live sparse notifications as the normal connected update path.
- Reconcile the full read-only snapshot only after 120 seconds without a successful rate-limit observation.
- Coalesce manual and scheduled full reads with one in-flight request and a five-second timeout.
- Reapply sparse notifications received during a full read so the newest live value wins.
- Show the last live notification, full sync, and displayed-value change time and path in Connection Health.

## Privacy And Scope

- Uses only stable `account/rateLimits/read` and `account/rateLimits/updated` plus existing in-memory connection state.
- Cadence observations remain memory-only and disappear when the app exits.
- No persistent diagnostics, IPC, new permission, new notification type, account mutation, thread API, or experimental API method.
- Existing notification thresholds remain opt-in, default to off, and suppress duplicate notifications.

## Verification

- Unit coverage includes the 120-second boundary, single in-flight gate, timeout invalidation, sparse/full race, visible-value signatures, freshness, unknown fields, notification deduplication, and English/Japanese resource parity.
- macOS 15 and macOS 26 CI passed build, all unit tests, privacy scan, package verification, and the published v1.0.0 artifact smoke test.
- The published v1.0.1 package passed checksum, ad-hoc signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release: [`v1.0.1`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.1).
- Release target: `586dfc6fa74cf8f5d0fcc4149011e2f5664f08d4`.
- ZIP SHA-256: `d450b7e9d64f001663e4ef82af3f2517bb434918676c6531337f937a12be9705`.
- Published artifact smoke test passed checksum, signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.
