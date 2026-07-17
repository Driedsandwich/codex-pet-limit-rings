# Codex Pet Limit Rings 1.0.6

Version 1.0.6 restores limit rings after the current ChatGPT desktop update changed the pet surface and stopped reporting top-level mascot dimensions in saved state.

## Highlights

- Supports the current ChatGPT pet state, where saved coordinates may be present without top-level mascot width, height, or offset metadata.
- Binds the live pet surface to the official `com.openai.codex` process instead of accepting generic ChatGPT windows.
- Uses the named `Codex Pet Mascot Effect` surface when available.
- When macOS redacts window names from the standalone accessory app, uses a permission-free fallback constrained by the official process, on-screen pet-effect layer, and bounded pet-relative geometry.
- Preserves the legacy overlay path, two-second visibility recovery, drag-follow behavior, and multi-display support.
- Excludes generic ChatGPT windows, third-party wrappers, and Stage Manager thumbnails from pet matching.

## Privacy And Scope

- Adds no new macOS permission.
- Reads only existing local Codex pet state and on-screen window metadata from the official ChatGPT process.
- Adds no credential read, persistent usage log, IPC, notification type, thread API, experimental API, reset consumption, or account mutation.
- Keeps the existing read-only and memory-only usage boundaries unchanged.

## Verification

- Main CI run [`29559887038`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29559887038) passed build, all unit tests, privacy checks, packaging, and the published v1.0.0 baseline smoke test on macOS 15 and macOS 26.
- Unit tests cover missing modern dimensions, historical-size recovery, safe size derivation, window-name redaction, official-process binding, wrapper rejection, Stage Manager exclusion, closed-pet visibility, and legacy behavior.
- The installed candidate restored an on-screen 198-by-198 ring panel around the current ChatGPT pet with notifications remaining off.
- The published artifact passed checksum verification, local-path sanitization, arm64 and macOS 15.0 inspection, ad-hoc signature verification, English/Japanese resource checks, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `5ada6aaf67caa6198908f6a062eca766a2503a61`.
- ZIP SHA-256: `e2d82096c47795ec33b557d6260ed37f4353cd39b210740ee79a7730a8292e3b`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.6` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.6), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
