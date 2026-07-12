# Changelog

Notable changes to `codex-pet-limit-rings` are recorded here.

## Unreleased

### Full Snapshot Deadline

- Anchor the connected 120-second full-snapshot reconcile to the last successful full read instead of any sparse live observation.
- Keep sparse notifications from postponing snapshot metadata refreshes across a rate-limit window rollover.
- Show full-snapshot metadata freshness separately from live value freshness in Connection Health.
- Preserve the single in-flight request gate, five-second timeout, sparse/full race merge, and bounded reconnect backoff.

## 1.0.1 - 2026-07-11

### Live Update Cadence

- Reconcile the full read-only rate-limit snapshot after 120 seconds without a successful live observation while app-server remains connected.
- Coalesce manual and scheduled full reads behind one five-second in-flight request gate.
- Buffer sparse live notifications received during a full read and reapply them to the returned snapshot, preserving the newest value without losing nullable metadata.
- Show the last live notification, full sync, and displayed-value change time and path in Connection Health, in memory only.
- Continue excluding durable diagnostics, IPC, new permissions or notification types, account mutation, thread APIs, and experimental APIs.

## 1.0.0 - 2026-07-11

### Compatibility & Data Trust

- Show the active Codex CLI version and explicit live, cached, local, or reconnecting source state.
- Show separate rate-limit and usage observation times with current, stale, or waiting labels.
- Classify connection failures into privacy-safe localized reasons without exposing process output or local paths.
- Tolerate unknown response fields, unknown reached-reason strings, and missing optional values through fixture coverage.
- Continue excluding thread/turn identifiers, per-thread usage, durable usage storage, reset consumption, account mutation, experimental APIs, and new notifications.
- Release CI now smoke-tests the published v0.9.0 artifact on macOS 15 and macOS 26.

## 0.9.0 - 2026-07-11

### Usage Milestones & Connection Health

- Show longest streak and longest running turn from the existing memory-only aggregate usage summary.
- Show explicit live, reconnecting, or poll-fallback connection state plus the last in-memory usage update time.
- Keep connection states distinguishable without color and localize the new rows in English and Japanese.
- Continue excluding thread/turn identifiers, per-thread usage, durable usage storage, reset consumption, account mutation, experimental APIs, and new notifications.
- Release CI now smoke-tests the published v0.8.0 artifact on macOS 15 and macOS 26.

## 0.8.0 - 2026-07-11

### Live Limit Updates & Usage Summary

- Keep one long-lived app-server stdio connection for rate-limit and account-usage reads.
- Apply sparse `account/rateLimits/updated` notifications without clearing nullable metadata from the latest full snapshot.
- Reconnect with bounded exponential backoff and use the 20-second local fallback poll only while disconnected.
- Show current streak, peak daily tokens, and lifetime tokens from the read-only account-usage summary.
- Continue excluding thread identifiers, thread resume/fork, durable usage storage, reset consumption, and experimental API methods.
- Release CI now smoke-tests the published v0.7.0 artifact on macOS 15 and macOS 26.

## 0.7.0 - 2026-07-11

### Daily Usage Insights

- Add a read-only Daily Usage submenu using stable app-server `account/usage/read`, refreshed every 15 minutes and retained only in memory.
- Show the latest 14 daily buckets as localized textual bar rows, including explicit loading, empty, and unsupported states.
- Keep the view accessible through motion-free updates, system contrast, and bars that remain distinguishable without color.
- Continue excluding thread usage, thread identifiers, transcript parsing, durable usage storage, notifications, experimental APIs, and account mutation.
- Release CI now smoke-tests the published v0.6.0 artifact on macOS 15 and macOS 26.

## 0.6.0 - 2026-07-11

### Limit Intelligence & Accessibility

- The menu now exposes read-only details for every rate-limit bucket, credit balance, monthly spend control, limit-reached reason, and available reset credits returned by Codex app-server.
- Optional local notifications cover 25% remaining, 10% remaining, and recovery. Notifications default to off, request permission only when enabled, and ignore cached or local fallback values.
- Reduced Motion removes animated pulse and glint effects. Increase Contrast and Differentiate Without Color receive stronger tracks, dashed secondary arcs, and alternate additional-limit markers.
- Menu and notification text are localized in English and Japanese.
- Diagnostics now report additional-limit count, feature availability, notification opt-in, and active accessibility display preferences without exposing balances, account identifiers, or paths.
- Release CI now smoke-tests the published v0.5.1 artifact on both macOS 15 and macOS 26.

## 0.5.1 - 2026-07-11

### Compatibility

- v0.5.1 source and package builds now use the `LSMinimumSystemVersion` value as an explicit Swift deployment target, producing an arm64 binary that runs on macOS 15 and newer instead of inheriting the build host's macOS 26 target.

## 0.5.0 - 2026-07-10

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
