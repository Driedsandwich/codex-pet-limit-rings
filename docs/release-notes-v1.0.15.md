# Codex Pet Limit Rings 1.0.15

ChatGPT 26.924 moved its bundled Codex CLI to `Contents/Resources/codex-cli/bin/codex`. The rings could still find the pet, but the previous bundled-CLI search missed that entrypoint and could not start the read-only app-server when no earlier CLI source was available.

Version 1.0.15 looks for the new entrypoint before the previous `Contents/Resources/codex` path in system and user installations of both ChatGPT.app and Codex.app. Explicit CLI overrides retain priority, followed by the existing Homebrew and PATH fallbacks. Pet geometry, account access, and recovery behavior are unchanged.

## Verification

With Codex 26.924.22138 and CLI 0.158.0-alpha.2.1, live diagnostics before and after installation reported `appServer=ready` and `petFrameReadable=true`; the user also confirmed the visible rings. Package, signature, offline-fixture, and test gates passed, followed by an independent code review.

## Distribution

The [v1.0.15 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.15) was published on 2026-09-27 at 14:04:21 UTC (release ID `397672145`), as the latest non-draft, non-prerelease release. Annotated tag `8fd40c324ffba7112596268656bbdd9a71a6cb27` targets merge commit `d8ec339acb458d39d5cc3263044bf597db85947d` (tree `559a8aa53c27d471f1a956432183131643e441cc`). [PR #52](https://github.com/Driedsandwich/codex-pet-limit-rings/pull/52) merged, and [PR CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/36324135834) and [main CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/36324300943) passed on macOS 15 and 26.

The ZIP contains version `1.0.15`, build `24`, for Apple silicon `arm64` on macOS `15.0` or later. It is ad-hoc signed and not notarized. ZIP SHA-256: `1f9ea91cb9602e5d6710db0011b3ff0240cab0027b3c1d47fca3101602eca1aa`. The GitHub asset digest matched, and a re-download from the public release passed the fixed-SHA artifact smoke test.

## Rollback

Preserve the working app, LaunchAgent, preferences, and Skill together before replacement. Restore that backup if needed; see [rollback.md](rollback.md) for the procedure. Version 1.0.14 does not search the new bundled CLI location, so it may lose app-server access when that is the only available CLI.
