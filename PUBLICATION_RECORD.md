# Publication Record

status: local-ready

## Source Commits

- Upstream baseline: `9962bd0c4df0c2f16e7e10af0b6c23db84702878`
- Upstream-compatible fix: `853af5b28fe598ae465e4a482f0e9e9ffbbbace0`
- Downstream 0.5.0 implementation: `9579e08b995a6d1e27099b6e359c581deefe7140`

## Publication Targets

- Downstream fork: pending
- Downstream CI: pending
- Downstream merge commit: pending
- Upstream pull request: pending
- Downstream tag and release: pending

## Lane Order

1. Create the public `Driedsandwich/codex-pet-limit-rings` fork from `petergpt/codex-pet-limit-rings`.
2. Add the fork as the writable `origin`; retain the original project as fetch-only `upstream` with a disabled push URL.
3. Push `codex/upstream-chatgpt-owner` and `codex/downstream-0.5.0` to the fork.
4. Open a downstream pull request into the fork's `main` branch and require CI to pass before merge.
5. Open the isolated compatibility pull request from `Driedsandwich:codex/upstream-chatgpt-owner` to `petergpt:main`.
6. After the downstream pull request is merged and verified, create tag and release `v0.5.0` from the verified merge commit.

Fork creation, each push, each pull request, merge, tag, and release remain separately auditable actions. Update this record with URLs and final commit identifiers after each action succeeds.

## Local Evidence Before Publication

- `tools/verify-release.sh`: passed for `v0.5.0`.
- Installed app diagnostics: app-server ready, current ChatGPT.app CLI detected, primary and secondary limits available.
- Runtime: LaunchAgent active, ring window aligned to the pet, error log empty.
- Rollback: previous `0.4.0` app and LaunchAgent backed up locally.

## Known Unknowns

- GitHub-hosted macOS CI has not run yet.
- Upstream maintainer response and merge timing are unknown.
- Code signing and notarization are not part of `v0.5.0`.
- Pet global-state keys remain an undocumented desktop implementation detail.
