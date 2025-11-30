# -xfce4

## XPRA / panel (taskbar) issue

There is a known issue where the XFCE panel may appear initially in XPRA sessions but disappear after interacting with the desktop. This repo includes a helper `bin/keep-panel-above.sh` which enforces the panel to stay on top (best-effort), and the startup script tries to disable panel autohide via `xfconf-query`.

If you run the desktop via `start-desktop.sh`, ensure `wmctrl` and `xdotool` are installed (the script now installs them) and the helper will run automatically.

Quick test steps:

1. Start or restart the desktop container and run `start-desktop.sh`.
2. Confirm the helper has started: `tail -f /tmp/keep-panel-above.log` or `ps aux | grep keep-panel-above.sh`.
3. Connect via XPRA and interact (click around). The panel should remain visible. If not, check `/tmp/keep-panel-above.log` and `/tmp/xpra.log` for hints.

If issues remain, you can tweak the helper or XFCE settings (panel properties) inside the session.