# Maintenance Strategy

Codex Pet Limit Rings is maintained as a focused companion for the ChatGPT desktop pet, not as a general usage dashboard or an alternative ChatGPT client.

## Product Boundary

- Keep the primary experience ambient: current limit rings attached to the live pet, with freshness and recovery state available when needed.
- Keep account access read-only and usage state memory-only. Do not consume reset credits, mutate the account, inspect prompts or transcripts, retain thread identifiers, or persist usage history.
- Treat the experimental Codex app-server methods listed in the documentation as a currently tested compatibility contract, not as a permanently stable public API.
- Keep detailed usage and connection diagnostics in the menu so the overlay remains legible and pet-like.

## Update Triggers

Start a compatibility update when one of these conditions is observed:

- A ChatGPT desktop, Codex CLI, or app-server change breaks a tested method, schema fixture, pet-window match, lifecycle recovery, or diagnostic.
- Full snapshots remain stale, manual refresh cannot recover, or the watchdog repeatedly replaces the connection.
- The LaunchAgent is running but the LaunchServices-owned app or its long-lived app-server child repeatedly exits or remains in initialization.
- The macOS 15 or macOS 26 CI job, packaging, artifact smoke, privacy, localization, accessibility, or path-sanitization check regresses.
- Published release facts, checksums, minimum-system requirements, or rollback instructions no longer match the public artifact.

For protocol or pet-surface changes, update fixtures and diagnostics before changing rendering behavior. Unknown fields, enums, and missing optional values should remain non-fatal unless the current compatibility contract requires otherwise.

Treat initialization and read deadlines as client-side recovery policy, not as an upstream app-server service-level guarantee. A timed-out full rate-limit read must retain the last valid snapshot as stale, close the old process, reject its generation's late callbacks, then initialize a fresh process before retrying. Do not immediately replay the request into the same process.

## Release Policy

- Use a patch release for a user-visible runtime, compatibility, privacy, packaging, or rollback correction.
- Documentation- or test-only maintenance does not require a new binary release unless it corrects a published artifact contract.
- Keep the pinned v1.0.0 long-term compatibility baseline under its documented legacy build-path exception, then separately require the current candidate and latest public artifact to pass all current gates.
- Keep upstream-compatible fixes isolated where practical. The broader downstream product remains independently maintained.

## Deferred Scope

The following remain out of scope unless a separate product decision establishes clear user value and a new privacy boundary:

- Per-thread usage, thread resume/fork, prompt or transcript inspection, and durable usage analytics.
- Reset-credit consumption, account mutation, additional notification classes, telemetry, or new permissions.
- More milestones, dense dashboard features, automatic updates, or wider platform ports.
- Signing and notarization infrastructure beyond the current distribution contract.

Behavior-preserving modularization and a fake app-server integration harness are preferred future hardening work when they measurably reduce compatibility risk; they should not expand data collection or the visible feature surface.

## Rollback Policy

Before replacing a working installation, preserve the app, LaunchAgent, preferences, and Skill in one timestamped backup. Retain the failed build separately, restore app bundles and Skills into clean destinations, and verify the restored version, launch state, pet alignment, and privacy-safe diagnostics before deleting either copy. The exact procedure is in [Rollback](rollback.md).
