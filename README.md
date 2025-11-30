# -xfce4

## XPRA / panel (taskbar) issue

There is a known issue where the XFCE panel may appear initially in XPRA sessions but disappear after interacting with the desktop. This repo includes a helper `bin/keep-panel-above.sh` which enforces the panel to stay on top (best-effort), and the startup script tries to disable panel autohide via `xfconf-query`.

If you run the desktop via `start-desktop.sh`, ensure `wmctrl` and `xdotool` are installed (the script now installs them) and the helper will run automatically.

Quick test steps:

1. Start or restart the desktop container and run `start-desktop.sh`.
2. Confirm the helper has started: `tail -f /tmp/keep-panel-above.log` or `ps aux | grep keep-panel-above.sh`.
3. Connect via XPRA and interact (click around). The panel should remain visible. If not, check `/tmp/keep-panel-above.log` and `/tmp/xpra.log` for hints.

If issues remain, you can tweak the helper or XFCE settings (panel properties) inside the session.

## 文字化け (XPRA メニューのアプリ名が化ける場合)

XPRA セッションのメニューでアプリ名が文字化けする（日本語が "ã¯..." のように表示される）場合は、\n
ロケールや文字エンコーディングが正しく渡されていないことが原因です。

対処法:

- `start-desktop.sh` は ja_JP.UTF-8 ロケールを生成し、XPRA の起動時に必要な環境変数 (LANG, LC_ALL, LC_CTYPE, LANGUAGE, PYTHONIOENCODING) を明示的に渡すようにしました。
- もし文字化けが続く場合は、コンテナ内で `locale -a` を実行して `ja_JP.utf8` が存在するか確認してください。ない場合は `sudo locale-gen ja_JP.UTF-8` と `sudo update-locale LANG=ja_JP.UTF-8` を試して再起動してください。
- 日本語フォントが不足していることも原因になるため、`fonts-noto-cjk` や `fonts-ipafont` 系のパッケージがインストールされていることを確かめてください。

これらの対策で多くのケースで XPRA のメニュー表示が正しくなります。