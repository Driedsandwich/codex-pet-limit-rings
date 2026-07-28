# Codex Pet Limit Rings 1.0.10 Candidate

Version 1.0.10 is a reliability-focused maintenance candidate. It strengthens refresh recovery, fallback trust, menu lifecycle safety, artifact verification, installation safety, and rollback without expanding the product or privacy boundary.

## Runtime Reliability

- Seed the in-memory fallback from successful live app-server snapshots and choose the newest valid cached or local fallback after a transient disconnect.
- Allow up to 15 seconds for app-server initialization while retaining the five-second rate-limit and usage read deadlines.
- Coalesce scheduled and manual account-usage reads behind one request, assign unique request IDs, reject older connection generations, and stop waiting after five seconds.
- Rebuild Connection Health only when its rows change and never mutate its structure while AppKit is tracking the menu.

## Release And Rollback Trust

- Pin the v1.0.0 provenance baseline and latest published v1.0.9 artifact by SHA-256 in CI.
- Apply strict archive, resource, bundle identifier, signature, local-path, preview, and privacy-safe diagnostic checks to current artifacts. The fixed v1.0.0 baseline retains only its documented pre-v1.0.4 local-path exception.
- Reject dangerous app paths before recursive removal, require successful ad-hoc signing and verification, and validate English/Japanese localization keys and format placeholders.
- Back up and restore the app, LaunchAgent, preferences, and installed local Skill as one reversible installation state while retaining the failed build for inspection.

## Boundaries

- No account mutation or reset-credit consumption.
- No thread or transcript access.
- No persistent usage history, telemetry, new notification type, permission, or network service.
- No change to the experimental app-server method set currently covered by the compatibility contract.

## Publication Status

This is an unpublished candidate. Release URL, target commit, package SHA-256, and public artifact evidence must be added only after the fixed-head merge and release gates succeed.
