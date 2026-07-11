# Codex Pet Limit Rings 1.0.1 Candidate

Version 1.0.1 is an unreleased maintenance candidate that reduces perceived rate-limit update delay without expanding the app's data or permission boundary.

## Highlights

- Keep live sparse notifications as the normal connected update path.
- Reconcile the full read-only snapshot only after 120 seconds without a successful rate-limit observation.
- Coalesce manual and scheduled full reads with one in-flight request and a five-second timeout.
- Reapply sparse notifications received during a full read so the newest live value wins.
- Show the last live notification, full sync, and displayed-value change time and path in Connection Health.

## Privacy And Scope

- Uses only stable `account/rateLimits/read` and `account/rateLimits/updated` plus existing in-memory connection state.
- Cadence observations remain memory-only and disappear when the app exits.
- No persistent logs, IPC, new permission, new notification type, account mutation, thread API, or experimental API.
- Existing notification thresholds remain opt-in and deduplicated.

## Candidate Verification

- Unit coverage includes the 120-second boundary, single in-flight gate, timeout invalidation, sparse/full race, visible-value signatures, freshness, unknown fields, notification deduplication, and English/Japanese resource parity.
- Package gates target Apple silicon `arm64` and macOS 15.0 or later on macOS 15 and macOS 26 CI.
- The published v1.0.0 artifact remains the rollback baseline until v1.0.1 is formally released.
