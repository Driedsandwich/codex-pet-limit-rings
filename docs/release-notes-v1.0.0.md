# Codex Pet Limit Rings 1.0.0

Version 1.0.0 makes the provenance and freshness of displayed data inspectable without expanding the app's data boundary.

## Highlights

- Sanitized Codex CLI version in Connection Health.
- Explicit live, cached, local, and reconnecting source states.
- Separate rate-limit and usage last-success times with current, stale, and waiting labels.
- Privacy-safe localized failure reasons.
- Forward-compatible decoding tests for unknown fields and missing optional values.

## Privacy And Scope

- Uses only the existing stable `account/rateLimits/read`, `account/rateLimits/updated`, and `account/usage/read` data plus in-memory connection state.
- No thread or turn identifiers, per-thread token events, resume/fork, prompt or transcript inspection, durable usage storage, reset-credit consumption, account mutation, experimental API method, new notification, or new permission.
- Diagnostics expose bounded version and state labels, never raw process output or user-specific paths.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release: [`v1.0.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.0).
- Release target: `84f4f4273a671f05ae0d0908b58d6e0cb8c2cd15`.
- ZIP SHA-256: `21d1eb306b3b3211c1911636e6cf3544bf94064af160b6f061949595b369229a`.
- Published artifact smoke test passed checksum, signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.
