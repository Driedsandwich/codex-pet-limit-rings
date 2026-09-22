# v1.0.14 Specification Audit

Reviewed on 2026-09-23 against the original companion boundary, the v0.5–v1.0.13
changelog and regression suite, ChatGPT 26.917.51856 (build 10492), and its bundled
Codex CLI 0.155.0-alpha.16. This is a compatibility and maintenance review, not a
claim that every historical desktop build was executed again.

## Preserved Contracts

| Area | Required behavior |
| --- | --- |
| Product | Native companion; no modification of the Codex/ChatGPT bundle or pet artwork |
| Pet detection | Live, on-screen official process evidence; persisted state alone never displays rings |
| Legacy compatibility | Saved overlay, named/redacted effects, compact pet, and centered oversized panel retain separate regression fixtures |
| Placement | Current size, multiple displays, control exclusion, drag mismatch recovery, and circular click-through rings |
| Limits | Optional short window, duration-classified weekly window, multi-bucket details, nullable fields, and unknown-field tolerance |
| Recovery | One in-flight full read, 120-second monotonic reconciliation, five-second read timeout, generation rejection, bounded reconnect |
| Privacy | Read-only account methods; no credentials, transcripts, thread IDs, reset consumption, telemetry, or durable usage history |
| Accessibility | English/Japanese, Reduced Motion, Increase Contrast, Differentiate Without Color, and explicit stale-state markers |
| Distribution | arm64, macOS 15+, ad-hoc signature, checksum, complete rollback backup, and macOS 15/26 CI |

## Corrections

| Finding | Resolution | Evidence |
| --- | --- | --- |
| Current native pet panel is asymmetric; center matching rejected it | Separate width/offset profile with strict process, layer, display, name, size, and position checks | Installed desktop layout code; two observed display geometries; classifier-to-frame regression tests; user confirmed corrected alignment |
| Unrelated compact controls could compete with a current drawing panel | Prefer a placeable verified panel and require saved-pet alignment for compact candidates when configured size exists | Near/far compact candidates, absent config, negative surface fixtures |
| Sparse updates could cross limit IDs or inherit another bucket's metadata | Merge only matching IDs and create new buckets from their own fields | Multi-bucket, legacy-only, and buffered-update regressions |
| Decoding each pipe chunk separately could lose split UTF-8 characters | Frame complete newline-delimited messages as bytes before decoding | Split multibyte, partial-line, and multi-line fixtures |
| Late pipe writes could raise an uncaught Objective-C exception | Shared throwing writer for all communication paths | Exact JSON framing and catchable closed-handle failure regression |
| Unchanged hover state invalidated the view on every mouse move | Invalidate only when readout visibility changes | View invalidation regression; no desktop input injection |
| An unrelated drag crossing the pet could start tracking | Require a matching mouse-down to establish the gesture | Drag-continuation regression |
| Async data could rebuild open detail menus | Defer structural updates while tracking, then render the newest state | Menu-delegate regressions |
| Source install stopped the working app before building its replacement | Build and validate a staged candidate and LaunchAgent first | Isolated staging/failure tests and packaged installation |
| Source backup omitted Skill; old incomplete backup could erase its presence | Complete backup marker; preserve unknown Skill state for older backups | Skill present/absent and incomplete-backup fixtures |
| ZIP instructions omitted a new LaunchAgent | Create the same LaunchServices-owned agent for fresh and existing installs | Structured plist construction and launch-contract checks |
| Shell syntax check examined only the first script | Iterate through every shell file | Full syntax gate and malformed-later-file rejection |
| Artifact gate checked only Mach-O minimum OS | Require plist and Mach-O deployment-target agreement | Mismatched deployment-target rejection |
| Automated previews could read the real account and fail on unrelated CLI startup timing | Use a synthetic local app-server and isolated state for artifact execution; assert the fixture version and a ready result | Current and pinned historical artifact execution; separate live installed-app diagnostics |

## Optimization Decisions

Keep the visible-only 10 fps animation, off-main cached state parsing, event-driven
pet updates, and cached hit testing. Remove unchanged-hover invalidation and the
duplicate `verify-release.sh` CI step: `package-release.sh` already runs that full
gate. No validation coverage is removed.

Do not infer a CPU percentage improvement from fewer invalidations. The earlier
[v1.0.12 measurements](performance-v1.0.12.md) remain historical evidence, not new
measurements. Native drawing cost, coalescing live geometry reads during drags, and
compiler optimization are candidates for a later measured performance change;
their benefit has not been established by this audit. Preserve live drag safety
instead of reducing its sampling without a behavioral comparison.

## Evidence And Limits

The account contract was cross-checked with the selected CLI's generated schema
and [OpenAI's app-server reference](https://learn.chatgpt.com/docs/app-server).
The service exposes the legacy single bucket alongside a keyed multi-bucket view;
the optional usage fields remain nullable. These are tested compatibility inputs,
not a promise that future app-server versions cannot change.

The current native panel was verified from the installed desktop layout and local
diagnostics. Its 1128px width and displaced center are version-specific facts, not
a heuristic for accepting arbitrary future windows. Unsupported geometry fails
closed. Older pet builds are covered by fixtures, not fresh installations.

Automated validation includes the full Swift suite, release-safety tests, package
verification, synthetic previews/diagnostics, and pinned historical artifacts.
The fixture checks packaging and client execution without real credentials or a
service connection; it does not stand in for the separate live compatibility
diagnostic. Host application presence, accessibility settings, and notification
preferences remain host-derived; only account transport and Codex state are
isolated. An initial v1.0.0 preview against the live CLI failed with a late pipe
write exception; that failed run is not counted as successful historical-runtime
compatibility. Published commit, CI, artifact checksum, and download verification
belong in [PUBLICATION_RECORD.md](../PUBLICATION_RECORD.md) after they finish.
AI did not directly inspect the Codex screen; the operator confirmed the restored
pet alignment. No generated screenshot is presented as a new desktop capture.
