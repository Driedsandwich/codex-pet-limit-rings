# Codex Pet Limit Rings 0.9.0 Candidate

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

## Candidate Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Publication URL, target commit, and ZIP SHA-256 remain intentionally unset until a separately approved release is created.
