# Codex Pet Limit Rings 0.5.1

This compatibility release rebuilds the macOS companion with an explicit macOS 15.0 deployment target. It does not change ring rendering, rate-limit retrieval, pet tracking, or privacy behavior.

## Compatibility Fix

- Builds the app, regression tests, release gate, and packaged binary for `arm64-apple-macosx15.0`.
- Records macOS 15.0 as `LSMinimumSystemVersion` in the app bundle.
- Verifies the packaged binary's load command, ad-hoc signature, arm64 architecture, checksum, and preview execution.
- Runs source and package verification on both macOS 15 and macOS 26 in GitHub Actions.

## Why This Release Is Needed

The published v0.5.0 binary inherited a macOS 26.0 minimum deployment target from its build host. Its source builds on macOS 15, but the downloaded app cannot launch there. Version 0.5.1 fixes the package target without replacing or mutating the v0.5.0 assets.

## Known Limits

- The app is ad-hoc signed and is not notarized.
- Pet position tracking relies on Codex desktop global-state keys that may change.
- SQLite remains a fallback; app-server is the preferred rate-limit source.
