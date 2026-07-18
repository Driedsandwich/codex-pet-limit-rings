# Codex Pet Limit Rings 1.0.8

Version 1.0.8 restores the rings when an in-place ChatGPT desktop app update replaces or relaunches the official application process, without weakening the live-window or privacy gates.

## Highlights

- Refreshes pet-window visibility when the official `com.openai.codex` application launches, terminates, hides, unhides, or activates.
- Replaces the pet-frame main-run-loop timer with a persistent two-second dispatch watchdog, so missed state-file or application events are recovered without restarting the companion app.
- Keeps the on-screen official pet window as the display requirement; saved open state and bounds remain positioning references only.
- Preserves pet-size tracking, drag following, multi-display behavior, and automatic hiding when the pet is not visible.

## Privacy And Scope

- Adds no screen capture, accessibility permission, API method, persistent usage storage, notification type, account mutation, thread API, or transcript access.
- Observes only official ChatGPT application lifecycle notifications and the existing permission-free window metadata used to locate the live pet.
- Existing usage reads remain read-only and memory-only, and threshold notifications remain opt-in and off by default.

## Verification

- Main CI run [`29623842615`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29623842615) passed build, all unit tests, privacy scan, package verification, and the published v1.0.0 artifact smoke test on macOS 15 and macOS 26.
- The published artifact passed checksum verification, local-path sanitization, ad-hoc signature verification, arm64 and macOS 15.0 inspection, English/Japanese resource checks, preview execution, and privacy-safe diagnostics.
- Rollback remains available by restoring the previously backed-up v1.0.7 app, LaunchAgent, and preferences; the installed local Skill remains unchanged.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `cf40d0f6d608ced1da1ca3279d7d5751643b856d`.
- ZIP SHA-256: `aa22968d32f82884c45098210e343c6c2ad13aeabdee8b4ff5f3e542894ddd31`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.8` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.8), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
