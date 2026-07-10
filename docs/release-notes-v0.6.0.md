# Codex Pet Limit Rings 0.6.0

Version 0.6.0 expands the macOS companion from two ambient rings into a read-only Codex limit-intelligence view while preserving the unpatched companion-app boundary.

## Added

- Full multi-bucket rate-limit details from Codex app-server.
- Read-only credit balance, monthly spend control, limit-reached reason, and reset-credit availability.
- Opt-in local notifications at 25%, 10%, and recovery, with duplicate suppression.
- Reduced Motion, Increase Contrast, Differentiate Without Color, English, and Japanese support.
- Expanded privacy-safe diagnostics and regression tests.

## Safety Boundary

- Notifications default to off and request permission only when enabled.
- Cached and SQLite fallback values do not trigger notifications.
- The app does not consume reset credits or perform account mutations.
- Daily account usage and per-thread token usage remain deferred.
- No API keys, ChatGPT bearer tokens, prompts, thread identifiers, or user paths are collected or published.

## Compatibility

- Apple silicon.
- macOS 15.0 or later.
- Ad-hoc signed and not notarized unless the final Release process explicitly changes that status.
