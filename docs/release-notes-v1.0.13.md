# Codex Pet Limit Rings 1.0.13 Candidate

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

- Candidate only. No `v1.0.13` tag or GitHub Release exists yet.
- Planned compatibility: Apple silicon `arm64`, macOS `15.0` or later, ad-hoc signed and not notarized.

## Rollback

Retain the published v1.0.12 app, LaunchAgent, preferences, and local Skill in a timestamped backup before candidate installation. Restore that backup and bootstrap the restored LaunchAgent if alignment, controls, refresh behavior, or resource use regresses. See [rollback.md](rollback.md).
