# Codex Pet Limit Rings 0.5.0

This compatibility release updates the macOS companion for current ChatGPT/Codex desktop builds while keeping the original pet-overlay design.

## Highlights

- Reads rate limits through the stable Codex app-server `account/rateLimits/read` protocol.
- Detects the Codex CLI inside current `ChatGPT.app`, legacy `Codex.app`, Homebrew, explicit overrides, and `PATH`.
- Stops reading `auth.json` or calling the undocumented `wham/usage` endpoint.
- Keeps a recent successful snapshot during short app-server failures and rejects expired data.
- Supports current and legacy SQLite log locations as a local fallback.
- Adds privacy-safe `--diagnose` output, regression tests, CI, a release gate, and rollback documentation.
- Tracks the live pet window by the `com.openai.codex` bundle identifier when the visible app name is `ChatGPT`.

## Verification

The local release gate covers shell syntax, plist metadata, six regression tests, Swift compilation, preview rendering, credential-path checks, secret-like material checks, license presence, and version consistency.

## Known Limits

- The app is ad-hoc signed and is not notarized.
- Pet position tracking relies on Codex desktop global-state keys that may change.
- SQLite is a fallback; app-server is the preferred data source.
