# Codex Pet Limit Rings 1.0.0 Candidate

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
- The candidate is not yet a GitHub Release.
