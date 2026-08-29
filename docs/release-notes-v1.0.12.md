# Codex Pet Limit Rings 1.0.12

Version 1.0.12 reduces idle and click-driven work while adding tightly gated compatibility paths for current compact and oversized ChatGPT pet surfaces.

## Performance

- Cache the read-only global pet-state snapshot by device, inode, size, and nanosecond modification time.
- Parse changed snapshots outside the main thread and coalesce overlapping watcher and watchdog refreshes.
- Test cached pet geometry before a global click can request live frame discovery.
- Animate only an effectively visible live pet panel, using monotonic time at 10 frames per second instead of an unconditional 30 frames per second.
- See the [measured release comparison](performance-v1.0.12.md) for hidden and current oversized-overlay visible CPU and sample results.

## Pet Surface Compatibility

- Recognize the current small layer-three pet surface only for the official ChatGPT process with strict size, aspect-ratio, display-containment, layer, and on-screen checks.
- Recognize the modern oversized transparent avatar panel only when official process, on-screen layer, saved open state, current display, screen-exceeding geometry, and saved-pet center alignment all agree; support the exact generic title and its permission-free redaction without treating either name state alone as pet evidence.
- Use the reconstructed pet bounds, not the giant panel, for click and drag hit testing.
- Reject normal ChatGPT windows, voice controls, Activity Stack, notifications, other processes, and off-display candidates.
- Preserve size tracking, drag following, lifecycle visibility, multi-display placement, circular click-through rings, and pet-control hit targets.

## Boundaries

- Keep `~/.codex/.codex-global-state.json` read-only.
- Use window metadata only; do not capture pixels or control contents.
- Add no account mutation, reset consumption, thread access, telemetry, persistent usage history, permission, or network service.
- The 2026-08-25 readout-drawing crash was not reproduced by repeated renderer-inclusive unit runs, so this release makes no speculative crash-path change.

## Publication Status

- Release: [`v1.0.12`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.12).
- Release target: `08754b592841bf0bfccd885fb688e8deec4342e9`.
- ZIP SHA-256: `bd5d5142887fd9d475a0b0f6a5d66be9c36c5f666b69239f42e56ade29880392`.
- Compatibility: Apple silicon `arm64`, macOS `15.0` or later, ad-hoc signed and not notarized.
- Main CI run [`33230792378`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/33230792378) passed the verifier, package checks, and pinned v1.0.0 and v1.0.9 public artifact smoke tests on macOS 15 and macOS 26.
- The published artifact smoke test passed checksum, archive allowlisting, local-path sanitization, signature, architecture, version, deployment-target, English/Japanese resources, preview execution, and privacy-safe diagnostic checks.

## Rollback

Keep the previous app, LaunchAgent, preferences, and local Skill in a timestamped backup before replacement. To roll back, restore the published v1.0.11 app and saved plist, restore preferences and Skill if needed, then bootstrap the restored LaunchAgent. See [rollback.md](rollback.md).
