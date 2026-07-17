# Codex Pet Limit Rings 1.0.7

Version 1.0.7 keeps the rings aligned when the current ChatGPT pet-size slider changes, including the maximum setting.

## Highlights

- Resizes and recenters the rings from the current live pet surface instead of retaining older saved dimensions.
- Uses the live mascot-effect center together with the current saved pet origin to derive the runtime pet size.
- Accepts the larger permission-free pet-effect geometry used at the maximum slider setting.
- Keeps historical pet size only as a fallback for missing or impossible live geometry.
- Preserves drag following, pet lifecycle visibility, multi-display positioning, and the current modern pet-surface safety gate.

## Privacy And Scope

- Adds no new macOS permission.
- Reads only the existing saved pet origin and on-screen window metadata from the official ChatGPT process.
- Adds no credential read, persistent usage log, IPC, notification type, thread API, experimental API, reset consumption, or account mutation.
- Keeps the existing read-only and memory-only usage boundaries unchanged.

## Verification

- Main CI run [`29591638335`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29591638335) passed build, all unit tests, privacy checks, packaging, and the published v1.0.0 baseline smoke test on macOS 15 and macOS 26.
- Unit tests cover small, large, maximum, missing, and invalid geometry together with drag, lifecycle, and multi-display behavior.
- The installed candidate was confirmed across the live pet-size slider, including a 319-by-319 ring panel at the maximum setting.
- The published artifact passed checksum verification, local-path sanitization, arm64 and macOS 15.0 inspection, ad-hoc signature verification, English/Japanese resource checks, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `96f16fc75c17426c5a752eafa2647ddfed21477c`.
- ZIP SHA-256: `5ea1d303b438c8243bec68f22d475a072085e1c08d7b7548421e04b186a78c0e`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.7` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.7), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
