# Publication Record

status: v0.5.1-macos15-candidate-verified

## Source Commits

- Upstream baseline: `9962bd0c4df0c2f16e7e10af0b6c23db84702878`
- Upstream-compatible fix: `853af5b28fe598ae465e4a482f0e9e9ffbbbace0`
- Downstream 0.5.0 implementation: `9579e08b995a6d1e27099b6e359c581deefe7140`
- Downstream release-packaging head published initially: `46edab5fc322a065abaa67eeaebddc7475b8e731`

## Publication Targets

- Downstream fork: `https://github.com/Driedsandwich/codex-pet-limit-rings`
- Upstream-fix branch: `codex/upstream-chatgpt-owner` at `853af5b28fe598ae465e4a482f0e9e9ffbbbace0`
- Downstream final feature head: `codex/downstream-0.5.0` at `ebef58e701326048924afa5649019c447e698efe`
- Downstream pull request: `https://github.com/Driedsandwich/codex-pet-limit-rings/pull/1` (merged)
- Downstream pull-request CI: passed (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29096616156`)
- Downstream merge commit: `97d9a67a00bafae67876927cfd2ff59e3f6043d6`
- Downstream main CI: passed (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29097404493`)
- Upstream pull request: `https://github.com/petergpt/codex-pet-limit-rings/pull/3` (ready for review, mergeable, no upstream checks configured)
- Downstream tag and release: `v0.5.0` at `https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.5.0`
- Release ZIP SHA-256: `9e2190944b16c1e5d176487d60e56b76b7545b3975abd52dbea1c22a36c1d871`
- Post-release hardening pull request: `https://github.com/Driedsandwich/codex-pet-limit-rings/pull/2` (merged as `29e6a7d1d90743771ace2ea920e5d6e16ebaa999`)
- Post-release matrix CI: push and pull-request runs passed on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29098720024`, `https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29098721714`)
- Post-release hardening main CI: passed (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29099211747`)
- v0.5.1 compatibility candidate branch: `codex/v0.5.1-macos15-compat`; verified implementation head `cb96dca7fe7720c2c6a18ec26c78f753b5eb536d` (deployment target macOS 15.0; live branch head retained by GitHub)
- v0.5.1 candidate pull request: `https://github.com/Driedsandwich/codex-pet-limit-rings/pull/3` (candidate review and merge history retained by GitHub)
- v0.5.1 candidate matrix CI: implementation-validation push and pull-request runs passed source and package execution on macOS 15 and macOS 26 (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29100063853`, `https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29100067189`); later PR-head status checks are retained by GitHub

## Lane Order

1. Create the public `Driedsandwich/codex-pet-limit-rings` fork from `petergpt/codex-pet-limit-rings`.
2. Add the fork as the writable `origin`; retain the original project as fetch-only `upstream` with a disabled push URL.
3. Push `codex/upstream-chatgpt-owner` and `codex/downstream-0.5.0` to the fork.
4. Open a downstream pull request into the fork's `main` branch and require CI to pass before merge.
5. Open the isolated compatibility pull request from `Driedsandwich:codex/upstream-chatgpt-owner` to `petergpt:main`.
6. After the downstream pull request is merged and verified, create tag and release `v0.5.0` from the verified merge commit.

Fork creation, both branch pushes, both pull requests, downstream merge, tag, and release completed on 2026-07-10. Upstream pull request #3 remains open for maintainer review.

## Local Evidence Before Publication

- `tools/verify-release.sh`: passed for `v0.5.0`.
- Release candidate: `CodexPetLimitRings-v0.5.0-macos-arm64.zip`.
- Final release SHA-256: `9e2190944b16c1e5d176487d60e56b76b7545b3975abd52dbea1c22a36c1d871`.
- Installed app diagnostics: app-server ready, current ChatGPT.app CLI detected, primary and secondary limits available.
- Runtime: LaunchAgent active, ring window aligned to the pet, error log empty.
- Rollback: previous `0.4.0` app and LaunchAgent backed up locally.

## Known Unknowns

- GitHub-hosted macOS CI passed for downstream pull request #1, merge commit `97d9a67`, and post-release hardening pull request #2. Pull request #2 uses `actions/checkout@v6` and explicit macOS 15/macOS 26 jobs.
- Upstream maintainer response and merge timing are unknown.
- The upstream repository does not currently report checks for pull request #3.
- Code signing and notarization are not part of `v0.5.0`.
- The published v0.5.0 binary has a minimum deployment target of macOS 26.0; macOS 15 is supported through the source-build path, and a broadly compatible binary requires a future release built with an explicit deployment target.
- Pet global-state keys remain an undocumented desktop implementation detail.
- The v0.5.1 compatibility candidate passes package execution on both macOS 15 and macOS 26. Tag creation and GitHub Release publication remain separately approved actions.
