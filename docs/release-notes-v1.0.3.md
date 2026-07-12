# Codex Pet Limit Rings 1.0.3

Version 1.0.3 keeps the rings accurate when Codex does not report a five-hour short-window limit, without expanding the app's data or permission boundary.

## Highlights

- Treats the short-window limit as optional instead of assuming every response has both short and weekly windows.
- Classifies the main windows by reported duration, so a weekly-only 10080-minute response remains a weekly ring even when Codex returns it in the `primary` field.
- Clears stale short-window display and notification history when a full snapshot omits that window and no newer live update reports it.
- Preserves sparse notifications received during a full read and restores a returned short window immediately from a later sparse update or full snapshot.
- Distinguishes reported usage from enforcement status in English and Japanese without claiming a permanent unlimited policy.

## Privacy And Scope

- Uses only stable read-only `account/rateLimits/read` and `account/rateLimits/updated` data already processed in memory.
- Adds no API method, persistent log, permission, notification type, account mutation, thread API, transcript access, or experimental API method.
- Existing threshold notifications remain opt-in, default to off, and discard history for limits that disappear.

## Verification

- Main CI run [`29204238395`](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29204238395) passed build, all unit tests, privacy scan, package verification, and the published v1.0.0 artifact smoke test on macOS 15 and macOS 26.
- A privacy-safe live read observed the weekly-only response, and the installed app correctly reports the short window absent and weekly window present.
- The published artifact passed checksum, ad-hoc signature, arm64 architecture, macOS 15.0 deployment target, English/Japanese resources, preview execution, and privacy-safe diagnostics.

## Compatibility

- Apple silicon `arm64`.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized.
- Release target: `a7293a5490ce84a982bf047af4454d926c9c27db`.
- ZIP SHA-256: `9a11a29a2828dff36f1e033236b75c4a9c7940319b3ff10aa11e42a0c72ebd6c`.

## Install And Rollback

- Download the ZIP and checksum from the [`v1.0.3` Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.3), verify both SHA-256 checks, and install only the verified app.
- Keep the previous app and LaunchAgent in a timestamped backup before replacement.
- To roll back, stop the LaunchAgent, restore the backed-up app and plist, and bootstrap the restored LaunchAgent again. The detailed procedure is in [rollback.md](rollback.md).
