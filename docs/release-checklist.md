# Release Checklist

## Source And Scope

- Confirm the branch is based on the intended upstream commit.
- Confirm [downstream-scope.md](downstream-scope.md) names the same upstream baseline and feature boundary.
- Review `git diff` and the commit list for unrelated files or generated artifacts.
- Keep upstream compatibility fixes separate from downstream-only features.
- Preserve `LICENSE` and upstream attribution.

## Automated Gate

Run:

```bash
tools/verify-release.sh
```

The gate must pass shell syntax, plist validation, regression tests, Swift compilation, preview rendering, credential-path checks, secret-like material checks, MIT license presence, and version consistency.

Build the release candidate and checksum:

```bash
tools/package-release.sh
```

Inspect the generated ZIP and `.sha256` file under ignored `dist/`. The v0.7.0 candidate is ad-hoc signed and not notarized; its eventual release notes must state that limitation. Confirm the packaged binary and `LSMinimumSystemVersion` both report macOS `15.0`, and confirm English and Japanese localization resources are present.

The packaging command verifies its checksum before returning. To repeat that check manually, run it from `dist/` so the relative archive name resolves:

```bash
(cd dist && shasum -a 256 -c CodexPetLimitRings-v0.7.0-macos-arm64.zip.sha256)
```

## Runtime Gate

After installing a release candidate, verify:

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
"$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

Confirm the menu-bar source is `App Server`, `Cached`, or `Local`, full limit details are read-only, Daily Usage shows a graph or explicit empty/unsupported state, notifications are off by default, the ring remains centered on the pet, and the error log is empty.

## Publication Gate

- Review the exact commit SHA and tag name.
- Review repository visibility, remote destination, and release notes.
- Confirm no local paths, logs, state files, screenshots with private content, or `tmp/` artifacts are included.
- Create the fork, push, upstream PR, and downstream release as separate operations.
- Record the fork URL, commit/tag, CI result, PR URL/status, and known limitations.

### Published v0.6.0 Evidence

- Release commit: `e479011e7dd18da64d59f5e3417f68b4d4405ce7`.
- Tag and Release: [`v0.6.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.6.0).
- Release ZIP SHA-256: `3230a6e83a02703bdc51f24737c5275d83baebd971abf84b7bde42ebf54764d1`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Final pull-request and push CI passed on macOS 15 and macOS 26.
- Merge-commit CI passed on macOS 15 and macOS 26.
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, and preview-execution checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.6.0
```

## Rollback

Follow [rollback.md](rollback.md) and verify the restored app before considering cleanup.
