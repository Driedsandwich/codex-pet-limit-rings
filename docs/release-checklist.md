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

Build the release package and checksum:

```bash
tools/package-release.sh
```

Inspect the generated ZIP and `.sha256` file under ignored `dist/`. The published v1.0.0 package is ad-hoc signed and not notarized. Confirm the packaged binary and `LSMinimumSystemVersion` both report macOS `15.0`, and confirm English and Japanese localization resources are present.

The packaging command verifies its checksum before returning. To repeat that check manually, run it from `dist/` so the relative archive name resolves:

```bash
(cd dist && shasum -a 256 -c CodexPetLimitRings-v1.0.0-macos-arm64.zip.sha256)
```

## Runtime Gate

After installing the published release, verify:

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

### Published v1.0.0 Evidence

- Release commit and target: `84f4f4273a671f05ae0d0908b58d6e0cb8c2cd15`.
- Tag and Release: [`v1.0.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.0).
- Release ZIP SHA-256: `21d1eb306b3b3211c1911636e6cf3544bf94064af160b6f061949595b369229a`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29135867267`).
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 1.0.0
```

### Published v0.9.0 Evidence

- Release commit and target: `8d3a6e7fcbe59a39ff65a43282a7ebfc1ae2c532`.
- Tag and Release: [`v0.9.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.9.0).
- Release ZIP SHA-256: `6226d5b1fce48c00267fd783ec58fabe7c5ae6a705a09fae00e24ec48611167a`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29132575449`).
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.9.0
```

### Published v0.8.0 Evidence

- Release commit and target: `660dc7bf43470d62829779216f76dc29ed7d8f4f`.
- Tag and Release: [`v0.8.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.8.0).
- Release ZIP SHA-256: `5020ba77564f0792414b3bd1c59e452d0431eb92cf3ef6ede0f70a417c473358`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29128292859`).
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.8.0
```

### Published v0.7.0 Evidence

- Release commit and target: `4929225a494e3f9f83ad138a54a9c663111cefea`.
- Tag and Release: [`v0.7.0`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.7.0).
- Release ZIP SHA-256: `70d56a43ea95b6dbc4b594d0d0695c2f6eb874e145aabd0496341bc60fd606cf`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29122478649`).
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.7.0
```

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
