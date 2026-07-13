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

Inspect the generated ZIP and `.sha256` file under ignored `dist/`. The published v1.0.4 package is ad-hoc signed and not notarized. Confirm the packaged binary and `LSMinimumSystemVersion` both report macOS `15.0`, confirm English and Japanese localization resources are present, and confirm the re-extracted binary contains no local build-machine path.

The packaging command verifies its checksum before returning. To repeat that check manually, run it from `dist/` so the relative archive name resolves:

```bash
(cd dist && shasum -a 256 -c CodexPetLimitRings-v1.0.4-macos-arm64.zip.sha256)
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

### Published v1.0.4 Evidence

- Release commit and target: `f4e60ef0e3aa099f64846eca0c45e9deb5322c28`.
- Tag and Release: [`v1.0.4`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.4).
- Release ZIP SHA-256: `e7bbe9ea1e9687c4bf3163f4841ae70bd37ae5561f972c28c957f19fb6c05598`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29214710222`).
- Installed-candidate checks covered live pet disappearance and restoration, alignment, notifications off, and privacy-safe diagnostics.
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 1.0.4
```

- A separate public-asset re-download scan confirmed that the ZIP-contained binary has no local build-machine path; the release verifier independently checks both its direct binary and a re-extracted packaged app binary.

### Published v1.0.3 Evidence

- Release commit and target: `a7293a5490ce84a982bf047af4454d926c9c27db`.
- Tag and Release: [`v1.0.3`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.3).
- Release ZIP SHA-256: `9a11a29a2828dff36f1e033236b75c4a9c7940319b3ff10aa11e42a0c72ebd6c`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29204238395`).
- A privacy-safe live read and packaged diagnostics confirmed the short window absent and weekly window present.
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 1.0.3
```

### Published v1.0.2 Evidence

- Release commit and target: `d88eabb77b7265928c74b9d51b69e5739bb632a8`.
- Tag and Release: [`v1.0.2`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.2).
- Release ZIP SHA-256: `46b0b8eda6ce48fbb46192f321edab4580571cd309f2ec09769482e942238e93`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29184418110`).
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 1.0.2
```

### Published v1.0.1 Evidence

- Release commit and target: `586dfc6fa74cf8f5d0fcc4149011e2f5664f08d4`.
- Tag and Release: [`v1.0.1`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.1).
- Release ZIP SHA-256: `d450b7e9d64f001663e4ef82af3f2517bb434918676c6531337f937a12be9705`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Merge-commit CI passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29140056357`).
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, English/Japanese resources, preview-execution, and privacy-safe diagnostic checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 1.0.1
```

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
