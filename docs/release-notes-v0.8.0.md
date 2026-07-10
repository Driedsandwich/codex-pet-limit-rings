# Codex Pet Limit Rings 0.8.0

Version 0.8.0 makes limit changes feel immediate while reducing repeated app-server process launches.

## Highlights

- One long-lived stable app-server stdio connection.
- Initial full rate-limit snapshot plus sparse live updates.
- Bounded exponential reconnect and disconnected-only local polling fallback.
- Current streak, peak day, and lifetime account-usage summaries alongside the 14-day graph.
- English/Japanese UI and existing accessibility behavior remain intact.

## Privacy And Scope

- Usage remains memory-only.
- No thread events, thread identifiers, resume/fork, prompt or transcript inspection, SQLite/JSONL usage parsing, or durable usage storage.
- No reset-credit consumption, account mutation, API keys, or experimental API methods.

## Compatibility

- Release: [`v0.8.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.8.0).
- Release target: `660dc7bf43470d62829779216f76dc29ed7d8f4f`.
- ZIP SHA-256: `5020ba77564f0792414b3bd1c59e452d0431eb92cf3ef6ede0f70a417c473358`.
- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Published artifact smoke test passed checksum, signature, architecture, version, deployment-target, preview-execution, and privacy-safe diagnostic checks.
