# Codex Pet Limit Rings 1.0.4

Version 1.0.4 prevents the companion rings from remaining at stale saved coordinates after Codex or its pet is no longer visible.

## Highlights

- Requires a matching live, on-screen Codex pet overlay before drawing the rings; persisted global-state bounds are used only as a search reference and mascot offset source.
- Hides the panel when Codex exits, the pet closes, or its overlay is hidden, minimized, or on another Space.
- Restores the rings through the existing state-file watcher and two-second fallback when the live pet returns.
- Preserves drag mismatch protection, predicted drag following, multi-display coordinates, and privacy-safe diagnostics.

## Privacy And Scope

- Adds no API method, permission, notification type, persistent log, account mutation, thread access, prompt access, transcript access, or experimental API dependency.
- Continues to use the existing read-only, memory-only rate-limit and account-usage paths.
- Existing notifications remain opt-in and off by default.
- Sanitizes build-machine source paths and verifies both the direct binary and the app re-extracted from a ZIP before publication.

## Verification

- Main CI run [`29214710222`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29214710222) passed build, all unit tests, privacy scan, package verification, and the published v1.0.0 artifact smoke test on macOS 15 and macOS 26.
- Unit tests cover stale persisted bounds, missing and restored live overlays, explicit pet close, hidden and terminated application state, multi-display coordinates, and drag mismatch rejection.
- The installed candidate hid its on-screen ring panel when Codex was hidden, restored it when Codex returned, and remained aligned to the live mascot center.
- The published artifact passed checksum, local-path sanitization, ad-hoc signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `f4e60ef0e3aa099f64846eca0c45e9deb5322c28`.
- ZIP SHA-256: `e7bbe9ea1e9687c4bf3163f4841ae70bd37ae5561f972c28c957f19fb6c05598`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.4` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.4), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app and LaunchAgent in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, and bootstrap the restored LaunchAgent again. The detailed procedure is in [rollback.md](rollback.md).
