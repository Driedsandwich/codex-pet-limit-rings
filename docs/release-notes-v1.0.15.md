# Codex Pet Limit Rings 1.0.15

ChatGPT 26.924 moved its bundled Codex CLI to `Contents/Resources/codex-cli/bin/codex`. The rings could still find the pet, but the previous bundled-CLI search missed that entrypoint and could not start the read-only app-server when no earlier CLI source was available.

Version 1.0.15 looks for the new entrypoint before the previous `Contents/Resources/codex` path in system and user installations of both ChatGPT.app and Codex.app. Explicit CLI overrides retain priority, followed by the existing Homebrew and PATH fallbacks. Pet geometry, account access, and recovery behavior are unchanged.

## Verification

With Codex 26.924.22138 and CLI 0.158.0-alpha.2.1, live diagnostics before and after installation reported `appServer=ready` and `petFrameReadable=true`; the user also confirmed the visible rings. Package, signature, offline-fixture, and test gates passed, followed by an independent code review.

## Distribution

The verified candidate is version `1.0.15`, build `24`, for Apple silicon `arm64` on macOS `15.0` or later. It is ad-hoc signed and not notarized. Candidate ZIP SHA-256: `1f9ea91cb9602e5d6710db0011b3ff0240cab0027b3c1d47fca3101602eca1aa`. Publication identity and results should be added after release.

## Rollback

Preserve the working app, LaunchAgent, preferences, and Skill together before replacement. Restore that backup if needed; see [rollback.md](rollback.md) for the procedure. Version 1.0.14 does not search the new bundled CLI location, so it may lose app-server access when that is the only available CLI.
