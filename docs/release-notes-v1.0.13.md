# Codex Pet Limit Rings 1.0.13

Version 1.0.13 corrects ring alignment for the modern oversized ChatGPT avatar surface without capturing pixels or adding permissions.

## Alignment

- Read only the bounded `[desktop] avatar-overlay-mascot-width-px` value from the existing local Codex configuration.
- Combine that width with ChatGPT's currently verified 192-by-208 pet canvas ratio and the saved pet origin.
- Keep the giant transparent window as strict identity evidence rather than assuming its center is the visible pet center.
- Retain the bounded v1.0.12 center reconstruction when the setting is absent, malformed, or outside the verified 80...224 range.

## Preserved Contracts

- Continue rejecting ordinary ChatGPT windows, voice controls, Activity Stack, notifications, other processes, and off-display candidates.
- Preserve direct and named mascot surfaces, full size tracking, drag following, lifecycle visibility, multiple displays, circular click-through rings, and pet-control hit targets.
- Keep app-server and account access read-only, notifications off by default, diagnostics memory-only, and Screen Recording and Accessibility permissions unnecessary.

## Publication Status

- Release: [`v1.0.13`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.13).
- Release target: `acf93391a925999e28df7888ece97e65fc26e92a`.
- ZIP SHA-256: `dd0ef8c31df8af0c5e3dbc2b5fcf614cfc4942f8191aec3f164eabbbc8c76a78`.
- Compatibility: Apple silicon `arm64`, macOS `15.0` or later, ad-hoc signed and not notarized.
- Main CI run [`33234562005`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/33234562005) passed the verifier, package checks, and pinned v1.0.0 and v1.0.9 public artifact smoke tests on macOS 15 and macOS 26.
- The published artifact smoke test passed checksum, archive allowlisting, local-path sanitization, signature, architecture, version, deployment-target, English/Japanese resources, preview execution, and privacy-safe diagnostic checks.

## Rollback

Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement. To roll back, restore the published v1.0.12 app and saved plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
