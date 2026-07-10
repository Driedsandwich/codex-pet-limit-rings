# Publication Record

status: pull-requests-open-ci-passed

## Source Commits

- Upstream baseline: `9962bd0c4df0c2f16e7e10af0b6c23db84702878`
- Upstream-compatible fix: `853af5b28fe598ae465e4a482f0e9e9ffbbbace0`
- Downstream 0.5.0 implementation: `9579e08b995a6d1e27099b6e359c581deefe7140`
- Downstream release-packaging head published initially: `46edab5fc322a065abaa67eeaebddc7475b8e731`

## Publication Targets

- Downstream fork: `https://github.com/Driedsandwich/codex-pet-limit-rings`
- Upstream-fix branch: `codex/upstream-chatgpt-owner` at `853af5b28fe598ae465e4a482f0e9e9ffbbbace0`
- Downstream verified code head: `codex/downstream-0.5.0` at `604263c16a499268c60eb9c03df94507131af5f9`
- Downstream pull request: `https://github.com/Driedsandwich/codex-pet-limit-rings/pull/1` (draft, mergeable)
- Downstream pull-request CI: passed (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29096488017`)
- Downstream merge commit: pending
- Upstream pull request: `https://github.com/petergpt/codex-pet-limit-rings/pull/3` (draft, mergeable, no upstream checks configured)
- Downstream tag and release: pending

## Lane Order

1. Create the public `Driedsandwich/codex-pet-limit-rings` fork from `petergpt/codex-pet-limit-rings`.
2. Add the fork as the writable `origin`; retain the original project as fetch-only `upstream` with a disabled push URL.
3. Push `codex/upstream-chatgpt-owner` and `codex/downstream-0.5.0` to the fork.
4. Open a downstream pull request into the fork's `main` branch and require CI to pass before merge.
5. Open the isolated compatibility pull request from `Driedsandwich:codex/upstream-chatgpt-owner` to `petergpt:main`.
6. After the downstream pull request is merged and verified, create tag and release `v0.5.0` from the verified merge commit.

Fork creation, both initial branch pushes, and both draft pull requests completed on 2026-07-10. Merge, tag, and release remain separate auditable actions. Update this record with URLs and final commit identifiers after each subsequent action succeeds.

## Local Evidence Before Publication

- `tools/verify-release.sh`: passed for `v0.5.0`.
- Release candidate: `CodexPetLimitRings-v0.5.0-macos-arm64.zip`.
- Release candidate SHA-256: `ad9c51d6efabd6f4da72013bd0419ef1c6d91bd6a792fcd68abe7512bb4a543b`.
- Installed app diagnostics: app-server ready, current ChatGPT.app CLI detected, primary and secondary limits available.
- Runtime: LaunchAgent active, ring window aligned to the pet, error log empty.
- Rollback: previous `0.4.0` app and LaunchAgent backed up locally.

## Known Unknowns

- GitHub-hosted macOS CI passed for downstream pull request #1; the workflow reports non-failing platform migration warnings for `actions/checkout@v4` and `macos-latest`.
- Upstream maintainer response and merge timing are unknown.
- The upstream repository does not currently report checks for pull request #3.
- Code signing and notarization are not part of `v0.5.0`.
- Pet global-state keys remain an undocumented desktop implementation detail.
