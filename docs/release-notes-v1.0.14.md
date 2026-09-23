# Codex Pet Limit Rings 1.0.14

Version 1.0.14 restores rings around ChatGPT 26.917's native pet panel and corrects
communication, interaction, and installation defects found during a specification
audit.

- Recognize the asymmetric native drawing panel without broadening ordinary-window matching; preserve the configured pet canvas as the interaction target.
- Isolate sparse updates by limit ID, preserve UTF-8 across pipe reads, and return catchable pipe-write errors.
- Skip unchanged-hover redraws, ignore unrelated drags, and defer open-menu structural updates.
- Validate the replacement before stopping the installed app, include Skill state in complete rollback backups, and preserve unknown state in older backups.
- Validate every shell script and require agreement between bundle and binary minimum OS. Remove the duplicated CI verification pass without removing checks.
- Use a synthetic offline app-server and isolated state for package previews and diagnostics; verify the installed app against the real bundled CLI separately.

Legacy pet profiles, optional short-window limits, weekly-only accounts, live
recovery, accessibility, English/Japanese, and the read-only privacy boundary are
retained. The [specification audit](specification-audit-v1.0.14.md) documents the
evidence and unmeasured performance opportunities.

## Distribution

Apple silicon `arm64`, macOS `15.0` or later; ad-hoc signed and not notarized.
Use the ZIP and SHA-256 asset from the
[v1.0.14 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.14).
Publication identity and CI results are recorded in
[PUBLICATION_RECORD.md](../PUBLICATION_RECORD.md).

- Source target: `c53255e47155930b8ebc83f97aa836a9d1b5ebf1`.
- ZIP SHA-256: `7e4ebe4b43fd9b73ea7668fa5394136736db58b30c95ed633aac09f6bf66bb47`.
- [Merge CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/35799230479) passed on macOS 15 and 26.
- Published bytes were downloaded again and passed the fixed-SHA artifact gate. Build 23 matched the installed app, whose separate live diagnostic reported a ready app-server and readable pet frame.

## Rollback

Preserve the working app, LaunchAgent, preferences, and Skill together before
replacement. Restore that backup if needed. The previous public release is
v1.0.13, whose pet matcher may not support ChatGPT 26.917. See
[rollback.md](rollback.md) for the complete procedure.
