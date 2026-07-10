# Codex Pet Limit Rings 0.8.0 Candidate

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

The candidate targets Apple silicon and macOS 15.0 or later. Packaging is ad-hoc signed and not notarized.
