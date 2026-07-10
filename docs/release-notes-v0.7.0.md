# Codex Pet Limit Rings 0.7.0

Version 0.7.0 adds a compact Daily Usage Insights view while preserving the companion app's read-only and privacy-minimizing boundary.

## Highlights

- Reads stable Codex app-server `account/usage/read` every 15 minutes.
- Shows the latest 14 daily token buckets as English/Japanese text-labelled bars.
- Includes explicit loading, empty, and unsupported states.
- Uses no animation or color-only meaning and follows system contrast behavior.

## Privacy And Scope

- Daily buckets remain in memory only and disappear when the app exits.
- No thread events, thread resume/fork, thread identifiers, prompts, transcript parsing, SQLite/JSONL usage analysis, or durable usage storage.
- No usage notifications, reset-credit consumption, account mutation, API keys, or experimental API methods.

The release targets `4929225a494e3f9f83ad138a54a9c663111cefea`, includes the verified arm64 ZIP with SHA-256 `70d56a43ea95b6dbc4b594d0d0695c2f6eb874e145aabd0496341bc60fd606cf`, and supports macOS 15.0 or later. Packaging is ad-hoc signed and not notarized. The [published Release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v0.7.0) passed the public artifact smoke test.
