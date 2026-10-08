# Codex Pet Limit Rings 1.0.17

The app can now detect new releases and guide you to the download page. This version also includes v1.0.16's fix for the changed ChatGPT 26.1002 pet panel.

## Updating From An Older Version

Versions through v1.0.16 cannot detect updates. Install v1.0.17 manually once using the [verified installation procedure](verified-installation.md). After that, the app checks at startup and every 24 hours while running. A newer release adds an upward arrow to the menu-bar icon and a menu item that opens its release page. You choose when to download and install it.

Automatic checks are enabled by default. Use `Check for App Updates…` for an immediate check. Turn off `Automatically Check for App Updates` to disable automatic checks; manual checks still work. Update notices appear only in the menu bar and menu; no macOS notification is sent or notification permission requested.

### 日本語での更新案内

v1.0.16以前をお使いの方は、今回だけ手動でv1.0.17へ更新してください。旧版には新しいリリースを検知する機能がありません。

自動確認は既定で有効です。更新後は起動時と、アプリの起動中に24時間ごとに新しい版を確認します。更新があるとメニューバーのリングアイコンに上向き矢印が付き、メニューから公開ページを開けます。すぐに確認したい場合は「アプリの更新を確認…」を選びます。「アプリの更新を自動で確認」を外すと自動確認を停止できます。ダウンロードとインストールはご自身で行う方式です。macOSの通知は送りません。

## Privacy And Verification

Update checks send only a fixed anonymous request for this fork's public GitHub release metadata. No Codex account data, usage, credentials, installed-version value, or machine identifier is sent. GitHub receives normal connection metadata such as the IP address. The dedicated ephemeral session uses no cookies, stored credentials, or disk cache; only the automatic-check preference is saved. Preview and diagnostic modes never start update checks.

Regression tests cover numeric versions, release/asset validation, redirects and size limits, request cancellation, failures, manual checks, periodic scheduling, stable menu structure, and accessible update indicators. Independent review and the full package gate passed. A probe using the same Swift transport fetched and validated the public GitHub response for v1.0.16, which was latest at the time of the probe. The published v1.0.17 ZIP was downloaded again and passed the fixed-SHA artifact smoke test.

The existing local v1.0.16 installation was not replaced during publication. Verification does not claim a full day of real-time observation, a v1.0.17 installation, or new live-account/visual testing.

## Distribution

Version/build: `1.0.17 / 26`. Apple silicon `arm64`, macOS `15.0` or later. Ad-hoc signed and not notarized.

Release target: `0dd8c9e6ff69d8a7ea32188be6b04e366e069ac6` (tree `e2af20ada1bc9a9ef5fd5a7ead528961b113dde8`). [PR #56](https://github.com/Driedsandwich/codex-pet-limit-rings/pull/56) is merged; [source push CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/37752069191) and [main CI](https://github.com/Driedsandwich/codex-pet-limit-rings/actions/runs/37752659102) passed on macOS 15 and 26.

The [v1.0.17 release](https://github.com/Driedsandwich/codex-pet-limit-rings/releases/tag/v1.0.17) was published on October 8, 2026 at 08:55:01 UTC as the latest stable release (release ID `406621833`). Download its ZIP and checksum, then follow the [verified installation procedure](verified-installation.md).

ZIP SHA-256: `b1631c363510028524b9196c33213b2839c62d366dedea9b41d8c9744ff20f31`.

Keep a backup before replacing an existing installation. [Rollback](rollback.md) restores that backup; v1.0.16 retains the current pet-panel fix but does not include release detection.
