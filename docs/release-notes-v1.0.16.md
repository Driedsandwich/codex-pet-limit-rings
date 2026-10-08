# Codex Pet Limit Rings 1.0.16

ChatGPT 26.1002 changed its native pet drawing panel. Earlier releases could still read usage limits but rejected the new panel, leaving the rings hidden.

Version 1.0.16 recognizes the new paired width/offset profile (1132/166) while retaining the earlier 1128/164 profile. It keeps the official-process, on-screen, layer, configured pet size, display, and alignment checks. The transparent panel identifies the pet; it never becomes the ring size or mouse target. No new permission or Codex configuration change is required.

## Verification

Package, regression, signature, localization, path-sanitization, and offline-fixture gates passed. The six verified source files match release target `75a81ac4467dc16b3f4b55e9e3654622b49fcd66`. [PR #54](https://github.com/Driedsandwich/codex-pet-limit-rings/pull/54) is merged, and [PR CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/37745709429) and [main CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/37745944630) passed on macOS 15 and 26.

The public ZIP was downloaded again and passed the fixed-SHA artifact smoke test. Publication used the previously verified package without rebuilding or reinstalling it.

Every file in the installed bundle matched the verified package. On Codex 26.1002.52244 with CLI 0.162.0-alpha.2, the installed app reported a ready app-server, current rate-limit and usage data, and a readable pet frame. The operator confirmed correct visible rings. These live checks are separate from the offline package fixtures.

## Distribution

Version/build: `1.0.16 / 25`. Apple silicon `arm64`, macOS `15.0` or later. Ad-hoc signed and not notarized.

ZIP SHA-256: `0518630feb3b8604814df288bb62324075c1b048afff88a10358627a5441fae5`.

Download the ZIP and checksum from the [v1.0.16 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.16). Follow [verified installation](verified-installation.md) to check the download, preserve the previous installation, and install it.

## Rollback

Preserve the working app, LaunchAgent, preferences, and Skill before replacement; see [rollback.md](rollback.md). Restoring v1.0.15 restores its files but does not make it recognize the changed ChatGPT 26.1002 panel.
