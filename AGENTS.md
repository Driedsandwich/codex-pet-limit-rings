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
tools/verify-release.sh
tools/package-release.sh
EXPECTED_MIN_OS=15.0 tools/smoke-release-artifact.sh 0.7.0
tmp/codex-pet-limit-rings --preview tmp/limit-rings-preview.png --size 164
```

For packaged installs, also run `tools/install-limit-rings.sh` and verify:

```bash
pgrep -fl CodexPetLimitRings
launchctl print "gui/$(id -u)/com.codex-pet.limit-rings" >/dev/null
```

Do not commit `tmp/`, local logs, screenshots, user Codex state, or generated private pet assets.
