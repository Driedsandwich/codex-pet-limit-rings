# Codex Pet Limit Rings 1.0.11

Version 1.0.11 keeps the usage rings visually complete while preserving access to the normal and contracted pet voice controls shown by current ChatGPT desktop builds.

## Pet Control Compatibility

- Detect the official normal and contracted `Codex Pet Voice Controls Backing` windows using the ChatGPT process, exact window name, layer, and tightly bounded pet-relative geometry.
- Keep the stricter normal-size geometry requirement when macOS redacts the control window name, avoiding a broader fallback match.
- Normalize a contracted control around its live center to a bounded minimum interaction target.
- Keep the ring panel click-through and the rings circular while excluding the effective control target from hover readouts and pet-drag tracking.
- Preserve live pet-size tracking, lifecycle visibility, drag following, and multi-display behavior.

## Boundaries

- Use permission-free window metadata only and do not capture screen pixels.
- Add no Accessibility or Screen Recording permission.
- Add no account mutation, reset consumption, thread or transcript access, telemetry, persistent usage history, notification type, or network service.
- Do not expose local paths, raw process output, tokens, or account identifiers.

## Publication Status

- Release: [`v1.0.11`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.11).
- Release target: `7df5bba91e1f1c5805da463164edc71aa995c7b4`.
- ZIP SHA-256: `7bb566878c8fa4e841ea504b4d09d5bdd551faeb7809a2ca68042706a161d439`.
- Compatibility: Apple silicon `arm64`, macOS `15.0` or later, ad-hoc signed and not notarized.
- Main CI run [`30689482025`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/30689482025) passed the verifier, package checks, and pinned v1.0.0 and v1.0.9 public artifact smoke tests on macOS 15 and macOS 26.
- The published artifact smoke test passed checksum, archive allowlisting, local-path sanitization, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks.

## Rollback

Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement. To roll back, restore the backed-up v1.0.10 app and plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
