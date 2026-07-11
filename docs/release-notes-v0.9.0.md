# Codex Pet Limit Rings 0.9.0

Version 0.9.0 makes aggregate usage milestones and connection freshness visible without expanding the app's data boundary.

## Highlights

- Longest streak and longest running turn alongside the existing account-usage summary.
- Explicit live, reconnecting, and disconnected poll-fallback states.
- Last in-memory usage update time.
- English/Japanese UI with words and symbols that remain distinguishable without color.

## Privacy And Scope

- Uses only the existing stable `account/usage/read` aggregate summary and in-memory connection state.
- No thread or turn identifiers, per-thread token events, resume/fork, prompt or transcript inspection, SQLite/JSONL usage parsing, or durable usage storage.
- No reset-credit consumption, account mutation, new notification, new permission, API key, or experimental API method.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release: [`v0.9.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.9.0).
- Release target: `8d3a6e7fcbe59a39ff65a43282a7ebfc1ae2c532`.
- ZIP SHA-256: `6226d5b1fce48c00267fd783ec58fabe7c5ae6a705a09fae00e24ec48611167a`.
- Published artifact smoke test passed checksum, signature, arm64 architecture, macOS 15.0 deployment-target, English/Japanese resources, preview execution, and privacy-safe diagnostics.
