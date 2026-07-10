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

## Runtime Gate

After installing a release candidate, verify:

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
"$HOME/Applications/CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings" --diagnose
```

Confirm the menu-bar source is `App Server`, `Cached`, or `Local`, the ring remains centered on the pet, and the error log is empty.

## Publication Gate

- Review the exact commit SHA and tag name.
- Review repository visibility, remote destination, and release notes.
- Confirm no local paths, logs, state files, screenshots with private content, or `tmp/` artifacts are included.
- Create the fork, push, upstream PR, and downstream release as separate operations.
- Record the fork URL, commit/tag, CI result, PR URL/status, and known limitations.

## Rollback

Follow [rollback.md](rollback.md) and verify the restored app before considering cleanup.
