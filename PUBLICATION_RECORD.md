# Publication Record

status: release-published-upstream-review-open

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

- GitHub-hosted macOS CI passed for downstream pull request #1 and merge commit `97d9a67`; the workflow reports non-failing platform migration warnings for `actions/checkout@v4` and `macos-latest`.
- Upstream maintainer response and merge timing are unknown.
- The upstream repository does not currently report checks for pull request #3.
- Code signing and notarization are not part of `v0.5.0`.
- Pet global-state keys remain an undocumented desktop implementation detail.
- This final record commit was made on the retained feature branch after pull request #1 merged; syncing it into `main` requires a later documentation-only pull request.
