# Security

`codex-pet-limit-rings` is local-first. Its primary rate-limit source is the bundled Codex app-server, and it does not read `~/.codex/auth.json` or copy ChatGPT bearer tokens.

The app reads pet-position state and may read the newest local Codex SQLite log as a fallback. Do not share Codex logs, global-state files, screenshots containing private prompts, or generated files from `tmp/` when filing issues.

If you report a security issue, include the smallest source-level description needed to reproduce it. Do not include bearer tokens, account identifiers, local paths, or local Codex data. `--diagnose` is designed to provide compatibility signals without printing those values.
