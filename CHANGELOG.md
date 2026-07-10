# Changelog

Notable changes to `codex-pet-limit-rings` are recorded here.

## Unreleased

### Limit Intelligence & Accessibility

- The menu now exposes read-only details for every rate-limit bucket, credit balance, monthly spend control, limit-reached reason, and available reset credits returned by Codex app-server.
- Optional local notifications cover 25% remaining, 10% remaining, and recovery. Notifications default to off, request permission only when enabled, and ignore cached or local fallback values.
- Reduced Motion removes animated pulse and glint effects. Increase Contrast and Differentiate Without Color receive stronger tracks, dashed secondary arcs, and alternate additional-limit markers.
- Menu and notification text are localized in English and Japanese.
- Diagnostics now report additional-limit count, feature availability, notification opt-in, and active accessibility display preferences without exposing balances, account identifiers, or paths.
- Release CI now smoke-tests the published v0.5.1 artifact on both macOS 15 and macOS 26.

### Compatibility

- v0.5.1 source and package builds now use the `LSMinimumSystemVersion` value as an explicit Swift deployment target, producing an arm64 binary that runs on macOS 15 and newer instead of inheriting the build host's macOS 26 target.

### Added

- Hover readouts now show a subtle reset countdown beneath the remaining percentage when reset data is available.
- A privacy-safe `--diagnose` command reports Codex app, CLI, app-server, pet-state, and limit availability without printing tokens or user paths.
- Regression tests cover current `ChatGPT.app` CLI discovery, app-server decoding, transient caching, cache expiry, and SQLite path selection.

### Changed

- Reset countdown text uses compact proportional styling so hour/minute labels stay readable without making the capsule feel busy.
- Rings now follow pet drags from the live Codex overlay window at drag-time, reducing visible lag when moving the pet.
- Rate limits now come from the stable `codex app-server` protocol first; direct `auth.json` and undocumented `wham/usage` access have been removed from the normal data path.
- The newest root or `sqlite/` Codex log database is selected for local fallback, and recent successful app-server data survives transient failures for up to 30 minutes while still current.

### Fixed

- Cross-display pet drags bridge brief live-overlay coordinate gaps from the mouse-to-pet offset instead of waiting for persisted pet state to catch up.
- Live pet-window tracking now identifies Codex by its `com.openai.codex` bundle identifier, so current builds whose visible application name is `ChatGPT` remain compatible while older `Codex`-named builds continue to work.
