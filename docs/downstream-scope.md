# Downstream Scope

## Baseline

- Upstream repository: `petergpt/codex-pet-limit-rings`
- Upstream baseline: `9962bd0c4df0c2f16e7e10af0b6c23db84702878`
- License: MIT; the original copyright and license text remain unchanged.

## Upstream-Compatible Commit

The first downstream parent commit changes live pet-window matching from the visible owner name `Codex` to the application bundle identifier `com.openai.codex`, while retaining the legacy owner-name fallback. This is intentionally isolated so it can be proposed upstream without the rest of the downstream feature set.

## Downstream-Only 0.5.x Work

- Use stable Codex app-server `account/rateLimits/read` as the primary rate-limit source.
- Discover the CLI in current `ChatGPT.app`, legacy `Codex.app`, Homebrew, explicit overrides, and `PATH`.
- Remove direct `auth.json`, bearer-token, and undocumented `wham/usage` access from the app.
- Keep a recent successful snapshot for up to 30 minutes only while its reset window remains current.
- Select the newest current or legacy SQLite log database for local fallback.
- Provide privacy-safe `--diagnose` output without tokens, account identifiers, or user paths.
- Add regression tests, CI, release verification, and rollback documentation.

## Deliberately Excluded

- No automatic reset-credit consumption or other account mutation.
- No Stop hook, prompt inspection, or raw transcript collection.
- No bundled credentials, API keys, screenshots with private content, or local Codex data.
- No automatic updater, code signing, notarization, Windows port, or per-turn usage overlay in 0.5.x.

## v0.6.0 Read-Only Expansion

- Decode and display full multi-bucket rate-limit snapshots, credits, individual monthly limits, reached reasons, and reset-credit availability.
- Keep notification permission opt-in and threshold notifications local to the Mac.
- Honor macOS accessibility display preferences and bundle English/Japanese UI resources.
- Do not consume reset credits or add any other account mutation.
- Defer daily and per-thread usage to a later, separately bounded design.

## v0.7.0 Daily Usage Insights

- Read stable `account/usage/read` through a short-lived app-server session every 15 minutes.
- Keep only the latest 14 normalized daily buckets in memory and display them as accessible English/Japanese menu rows.
- Provide loading, empty, and unsupported states without adding permissions.
- Exclude `thread/tokenUsage/updated`, thread resume/fork, thread identifiers, transcript or SQLite/JSONL usage parsing, durable usage storage, usage notifications, experimental APIs, and account mutation.

## v0.8.0 Live Limit Updates & Usage Summary

- Keep one long-lived stable stdio app-server connection and apply sparse `account/rateLimits/updated` notifications to the latest full snapshot.
- Use bounded exponential reconnect delays and retain the local 20-second poll only as a disconnected fallback.
- Read daily buckets and aggregate usage summary fields through the same connection every 15 minutes, retaining them in memory only.
- Display current streak, peak daily tokens, and lifetime tokens in English and Japanese without adding notification or storage permissions.
- Continue excluding thread events and identifiers, resume/fork, reset-credit consumption, experimental APIs, and account mutation.

## v0.9.0 Usage Milestones & Connection Health

- Display longest streak and longest running turn from the existing stable aggregate usage summary without adding another request or storage path.
- Label live, reconnecting, and disconnected poll-fallback states using existing in-memory connection and source state.
- Show the last in-memory usage observation time and keep all status presentation English/Japanese and distinguishable without color.
- Continue excluding thread/turn identifiers, per-thread token events, resume/fork, durable usage storage, reset-credit consumption, new notifications, experimental APIs, and account mutation.

## Known Compatibility Risks

- The Codex app-server command is still labeled experimental even though the rate-limit methods used here are present in its stable generated schema.
- Pet placement still relies on Codex desktop global-state keys that are not a published compatibility contract.
- SQLite event structure is a fallback only and may change; app-server remains the preferred source.

When these inputs change, update fixtures and diagnostics before changing rendering behavior.
