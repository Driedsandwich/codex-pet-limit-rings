# v1.0.12 Performance Validation

Observed on 2026-08-29 on the same Apple-silicon Mac and the same hidden/off-Space pet condition. Values are measurements, not projections. Each stage used the inner `CodexPetLimitRings.app/Contents/MacOS/CodexPetLimitRings` process rather than the `open -W` LaunchAgent wrapper.

| Stage | Change present | 12 one-second CPU samples | 8-second sample: JSON parser | 8-second sample: blur kernel |
|---|---|---:|---:|---:|
| Published v1.0.11 | Neither performance fix | 10.51% average, 14.20% max | 162 | 62 |
| Cache-only commit `ee00e57` | Snapshot cache, off-main parse, click gate | 7.58% average, 8.50% max | 0 | 54 |
| v1.0.12 candidate | Cache path plus visible-only 10 fps | 0.10% average, 0.30% max | 0 | 18 |

An independent later 12-sample candidate repeat measured 1.44% average and 6.80% maximum; the process lifetime at that point was 7 CPU seconds over 4 minutes 15 seconds. The idle-average target of less than 3% was met in both candidate samples. Because the current pet window remained outside the active Space during the final measurement, the result demonstrates the required timer shutdown and parse suppression while hidden; it does not claim an on-screen animation average or an automated click-storm result. The global-click ordering and visible-animation gates are covered by unit tests, and on-screen interaction remains a release-candidate observation gate.

The 2026-08-25 readout-drawing SIGABRT did not recur across 20 consecutive renderer-inclusive full unit-suite runs. No deterministic reproduction fixture was established, so v1.0.12 intentionally contains no speculative crash-path change.

The shadow pre-rendering proposal was not implemented because the measured hidden/off-Space idle target was already met by the two lower-risk fixes. It remains a conditional follow-up only if an on-screen measurement exceeds the target or visual urgency states show unacceptable cost.
