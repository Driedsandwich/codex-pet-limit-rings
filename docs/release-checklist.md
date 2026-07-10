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

Inspect the generated ZIP and `.sha256` file under ignored `dist/`. Version `0.6.0` is ad-hoc signed and not notarized; the release notes must state that limitation. Confirm the packaged binary and `LSMinimumSystemVersion` both report macOS `15.0`, and confirm English and Japanese localization resources are present.

The packaging command verifies its checksum before returning. To repeat that check manually, run it from `dist/` so the relative archive name resolves:

```bash
(cd dist && shasum -a 256 -c CodexPetLimitRings-v0.6.0-macos-arm64.zip.sha256)
```

## Runtime Gate

After installing a release candidate, verify:

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
"$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

Confirm the menu-bar source is `App Server`, `Cached`, or `Local`, full limit details are read-only, notifications are off by default, the ring remains centered on the pet, and the error log is empty.

## Publication Gate

- Review the exact commit SHA and tag name.
- Review repository visibility, remote destination, and release notes.
- Confirm no local paths, logs, state files, screenshots with private content, or `tmp/` artifacts are included.
- Create the fork, push, upstream PR, and downstream release as separate operations.
- Record the fork URL, commit/tag, CI result, PR URL/status, and known limitations.

### Published v0.5.1 Evidence

- Release commit: `8974665631f6ef9923ef2233bf82246e840330e3`.
- Tag and Release: [`v0.5.1`](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.5.1).
- Release ZIP SHA-256: `ff1081de8e1e26ede32337d4cadec8b98a7b8bcc1be87f592d28b6beb70c165d`.
- Packaged architecture: Apple silicon `arm64`.
- Packaged minimum OS: macOS `15.0` in both `LSMinimumSystemVersion` and the Mach-O build command.
- Signing status: ad-hoc signed and not notarized.
- Final pull-request and push CI passed on macOS 15 and macOS 26.
- Merge-commit CI passed on macOS 15 and macOS 26.
- The published artifact smoke test passed checksum, signature, architecture, version, deployment-target, and preview-execution checks:

```bash
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.5.1
```

## Rollback

Follow [rollback.md](rollback.md) and verify the restored app before considering cleanup.
