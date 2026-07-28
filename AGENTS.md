# Codex Pet Limit Rings Agent Notes

## Goal

This repository packages `codex-pet-limit-rings`: a native macOS companion app that draws usage-limit rings around the current Codex pet without patching Codex.

## Primary Contract

- Keep the Codex app bundle unmodified.
- Treat `tools/codex-pet-limit-rings.swift` as the app source.
- Treat `tools/install-limit-rings.sh` and `tools/uninstall-limit-rings.sh` as the public install/uninstall path.
- Treat `skills/codex-pet-limit-rings/SKILL.md` as the reusable Codex-agent workflow.
- Keep weather-pet code under `experiments/weather-pets/`; it is not the main package.

## Done When

For app changes, verify:

```bash
bash -n tools/*.sh
deployment_target="$(plutil -extract LSMinimumSystemVersion raw tools/CodexPetLimitRings-Info.plist)"
swiftc -parse-as-library -target "arm64-apple-macosx$deployment_target" tools/codex-pet-limit-rings.swift -o tmp/codex-pet-limit-rings -framework AppKit -framework UserNotifications -lsqlite3
tools/test-limit-rings.sh
bash tools/test-release-safety.sh
tools/verify-release.sh
tools/package-release.sh
EXPECTED_MIN_OS=15.0 EXPECTED_SHA256=21d1eb306b3b3211c1911636e6cf3544bf94064af160b6f061949595b369229a ALLOW_LEGACY_LOCAL_PATHS=1 tools/smoke-release-artifact.sh 1.0.0
EXPECTED_MIN_OS=15.0 EXPECTED_SHA256=e085c5ee47e9a8ebafbc8cb6d2788d673b26c85ab1b520792bbe5da8b42aa273 tools/smoke-release-artifact.sh 1.0.9
tmp/codex-pet-limit-rings --preview tmp/limit-rings-preview.png --size 164
```

The `ALLOW_LEGACY_LOCAL_PATHS=1` exception is accepted by the verifier only for
v1.0.0 at the fixed SHA-256 shown above. That provenance artifact predates
release-path sanitization. Current and future artifacts must pass the local-path
check, and locally packaged candidates must pass the same core artifact verifier
as downloaded releases.

For packaged installs, also run `tools/install-limit-rings.sh` and verify:

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
```

Do not commit `tmp/`, local logs, screenshots, user Codex state, or generated private pet assets.
