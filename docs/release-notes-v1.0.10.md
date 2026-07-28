# Codex Pet Limit Rings 1.0.10

Version 1.0.10 is a reliability-focused maintenance release. It strengthens refresh recovery, fallback trust, menu lifecycle safety, artifact verification, installation safety, and rollback without expanding the product or privacy boundary.

## Runtime Reliability

- Seed the in-memory fallback from successful live app-server snapshots and choose the newest valid cached or local fallback after a transient disconnect.
- Allow up to 15 seconds for app-server initialization while retaining the five-second rate-limit and usage read deadlines.
- Start the installed GUI app through LaunchServices while the LaunchAgent waits, preventing the repeated initialization timeout observed when launchd directly executes the inner app binary.
- Coalesce scheduled and manual account-usage reads behind one request, assign unique request IDs, reject older connection generations, and stop waiting after five seconds.
- Rebuild Connection Health only when its rows change and never mutate its structure while AppKit is tracking the menu.

## Release And Rollback Trust

- Pin the v1.0.0 provenance baseline and published v1.0.9 compatibility baseline by SHA-256 in CI.
- Apply strict archive, resource, bundle identifier, signature, local-path, preview, and privacy-safe diagnostic checks to current artifacts. The fixed v1.0.0 baseline retains only its documented pre-v1.0.4 local-path exception.
- Reject dangerous app paths before recursive removal, require successful ad-hoc signing and verification, and validate English/Japanese localization keys and format placeholders.
- Back up and restore the app, LaunchAgent, preferences, and installed local Skill as one reversible installation state while retaining the failed build for inspection.

## Boundaries

- No account mutation or reset-credit consumption.
- No thread or transcript access.
- No persistent usage history, telemetry, new notification type, permission, or network service.
- No change to the experimental app-server method set currently covered by the compatibility contract.

## Publication Status

- Release: [`v1.0.10`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.10).
- Release target: `6a95bf462acd4c8acb0cf26d5b2dad273e0a4439`.
- ZIP SHA-256: `ad4c87912b085695eeda10bba6e911b235e1077d11059d6002fb6d1838a0d3df`.
- Compatibility: Apple silicon `arm64`, macOS `15.0` or later, ad-hoc signed and not notarized.
- The published artifact smoke test passed checksum, archive allowlisting, local-path sanitization, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks.
