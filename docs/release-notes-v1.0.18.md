# v1.0.18: Restore Rings On Multiple Displays

ChatGPT 26.1007 changed its native pet drawing panel to cover the selected display when multiple displays are connected. Earlier Limit Rings versions rejected that panel, so the rings could disappear even while the pet and usage data remained available.

This version recognizes the new panel using the official process, on-screen state, window layer, current display rectangle, and read-only pet visibility and size settings. The saved pet origin and bounded canvas size determine ring placement. The full display never becomes the mouse or drag target. Earlier panel profiles remain supported.

## 日本語の更新案内

複数の画面を接続したMacで、Codex更新後にペット周囲のリングが消える問題に対応します。ペットの描画領域が画面全体へ変わったことが原因です。リングはペットの位置とサイズに合わせて表示します。

v1.0.17の利用者には、既存の更新確認機能から新しい版を案内します。それ以前の版は公開ページから手動で更新してください。更新前には、[導入手順](verified-installation.md)に従って現在のアプリを退避してください。

## Scope And Limitations

The new profile requires a valid configured pet width, an explicitly enabled desktop pet visibility setting, and a saved display rectangle matching a currently attached display. Unknown or incomplete state stays hidden. ChatGPT's full-display panel can also contain other controls, so window metadata does not independently prove that the pet sprite is visible in every transient Quick Chat or orbit state.

No ChatGPT files, credentials, permissions, or settings are changed. No screen pixels are captured. Release checks and user-controlled installation from v1.0.17 remain unchanged.

## Distribution

Version/build: `1.0.18 / 27`. Apple silicon `arm64`, macOS `15.0` or later. Ad-hoc signed and not notarized.

Regression tests, independent static review, and the full package gate passed. The installed bundle matches the verified package, with the previous installation preserved for rollback. Live diagnostics on ChatGPT 26.1007.21159 / CLI 0.162.0-alpha.17.2 reported a ready app-server, current usage data, and a readable pet frame. The operator confirmed rings at the correct pet-relative position. The public ZIP was downloaded again and passed the fixed-SHA artifact smoke test.

The [v1.0.18 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.18) was published at 2026-10-09 15:39:04 UTC (October 10 JST). Release target: `234229a1ec8ef9e582abc99cc5b524cd6d790dc4` (tree `bbcda93a14d929f437c40fdb4c8c0355609c98c6`). [PR #58](https://github.com/Driedsandwich/codex-pet-limit-rings/pull/58) is merged and [main CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/37952988268) passed on macOS 15 and 26.

ZIP SHA-256: `cd449e6c9f701a59ceccd0601cad606f7d2c850de1ea6d57b00d1199ae022e8b`.

Follow [Verified Installation And Rollback](verified-installation.md) to verify and install the ZIP. An older backup restores the previous app files but does not restore compatibility with the new full-display pet panel.
