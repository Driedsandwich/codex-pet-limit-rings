# Publication Record

status: v0.5.1-released

## Source Commits

- Upstream baseline: `9962bd0c4df0c2f16e7e10af0b6c23db84702878`
- Upstream-compatible fix: `853af5b28fe598ae465e4a482f0e9e9ffbbbace0`
- Downstream 0.5.0 implementation: `9579e08b995a6d1e27099b6e359c581deefe7140`
- Downstream release-packaging head published initially: `46edab5fc322a065abaa67eeaebddc7475b8e731`
- v0.5.1 release merge commit: `8974665631f6ef9923ef2233bf82246e840330e3`

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
- v0.5.1 compatibility branch: `codex/v0.5.1-macos15-compat` at final pull-request head `1761c0f217327dbfa040700b166c5443c8d2368d`
- v0.5.1 pull request: `https://github.com/Driedsandwich/codex-pet-limit-rings/pull/3` (merged as `8974665631f6ef9923ef2233bf82246e840330e3`)
- v0.5.1 final push and pull-request matrix CI: macOS 15 and macOS 26 passed source and package execution (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29104843374`, `https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29104845990`)
- v0.5.1 merge-commit matrix CI: macOS 15 and macOS 26 passed (`https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/29104947901`)
- v0.5.1 tag and release: `v0.5.1` at `https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.5.1`
- v0.5.1 Release ZIP SHA-256: `ff1081de8e1e26ede32337d4cadec8b98a7b8bcc1be87f592d28b6beb70c165d`
- v0.5.1 Release binary minimum OS: macOS `15.0`
- v0.5.1 published artifact smoke test: passed with checksum, signature, arm64 architecture, version, minimum OS, and preview execution verified

## Lane Order

1. Create the public `Driedsandwich/codex-pet-limit-rings` fork from `petergpt/codex-pet-limit-rings`.
2. Add the fork as the writable `origin`; retain the original project as fetch-only `upstream` with a disabled push URL.
3. Push `codex/upstream-chatgpt-owner` and `codex/downstream-0.5.0` to the fork.
4. Open a downstream pull request into the fork's `main` branch and require CI to pass before merge.
5. Open the isolated compatibility pull request from `Driedsandwich:codex/upstream-chatgpt-owner` to `petergpt:main`.
6. After the downstream pull request is merged and verified, create tag and release `v0.5.0` from the verified merge commit.
7. Merge the macOS 15 compatibility pull request, verify its main CI, and create tag and release `v0.5.1` from the verified merge commit.

Fork creation, both branch pushes, downstream pull requests, downstream merges, and releases through v0.5.1 are complete. Upstream pull request #3 remains open for maintainer review.

## Release Evidence

- `tools/verify-release.sh` and `tools/package-release.sh`: passed for `v0.5.1` from merge commit `8974665631f6ef9923ef2233bf82246e840330e3`.
- Release archive: `CodexPetLimitRings-v0.5.1-macos-arm64.zip`.
- Final v0.5.1 SHA-256: `ff1081de8e1e26ede32337d4cadec8b98a7b8bcc1be87f592d28b6beb70c165d`.
- The published v0.5.1 artifact passed checksum, signature, arm64 architecture, version, macOS 15.0 deployment-target, and preview-execution checks.
- v0.5.0 remains available as historical provenance with unchanged assets and SHA-256 `9e2190944b16c1e5d176487d60e56b76b7545b3975abd52dbea1c22a36c1d871`.

## Known Unknowns

- GitHub-hosted macOS CI passed for downstream pull request #1, merge commit `97d9a67`, and post-release hardening pull request #2. Pull request #2 uses `actions/checkout@v6` and explicit macOS 15/macOS 26 jobs.
- Upstream maintainer response and merge timing are unknown.
- The upstream repository does not currently report checks for pull request #3.
- The v0.5.1 app is ad-hoc signed and not notarized.
- The historical v0.5.0 binary has a minimum deployment target of macOS 26.0; v0.5.1 supersedes it with a macOS 15.0 minimum deployment target.
- Pet global-state keys remain an undocumented desktop implementation detail.
- Upstream pull request #3 remains outside the downstream v0.5.1 release and awaits maintainer review.
