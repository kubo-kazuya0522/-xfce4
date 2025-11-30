#!/usr/bin/env bash
set -e

echo "[*] Start script — ensure minimal prerequisites exist"

# Only run heavy package installs when key binaries are missing (fast path)
if ! command -v xpra >/dev/null 2>&1 || ! command -v websockify >/dev/null 2>&1; then
  echo "[*] Installing packages (first run)..."
  sudo apt-get update -y
  sudo apt-get install -y xfce4 xfce4-goodies tightvncserver novnc websockify dbus-x11 \
    x11-xserver-utils xfce4-terminal pulseaudio xpra fonts-noto-cjk gir1.2-rsvg-2.0 librsvg2-2 \
    wmctrl xdotool language-pack-ja fonts-ipafont wget tar xz-utils bzip2 || true
else
  echo "[*] packages already available — skipping apt install"
fi

# Generate locale only if missing (best-effort)
if ! locale -a | grep -qi "ja_JP\.utf"; then
  sudo locale-gen ja_JP.UTF-8 || true
  sudo update-locale LANG=ja_JP.UTF-8 || true
fi

# === VNC Setup ======================================================
VNC_DIR="$HOME/.vnc"
mkdir -p "$VNC_DIR"
echo "vncpass" | vncpasswd -f > "$VNC_DIR/passwd" || true
chmod 600 "$VNC_DIR/passwd"

cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
dbus-launch startxfce4 &
EOF
chmod +x "$VNC_DIR/xstartup"

vncserver -kill :1 2>/dev/null || true
xpra stop :100 2>/dev/null || true
pkill Xvfb 2>/dev/null || true

echo "[*] Starting VNC..." && vncserver :1 -geometry 1366x768 -depth 24

echo "[*] Starting noVNC (6080)"
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

pulseaudio --kill 2>/dev/null || true
pulseaudio --start --exit-idle-time=-1 || true

# === XPRA ==========================================================
echo "[*] Starting XPRA on port 10000..."
xpra stop :100 2>/dev/null || true

# ロケール環境変数（生成に失敗した場合は C.UTF-8 にフォールバック）
export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
# Ensure Python and C libraries prefer UTF-8 when reading/writing text
export LC_CTYPE=ja_JP.UTF-8
export PYTHONIOENCODING=utf-8
# Ensure the ja_JP.UTF-8 locale is actually available in the runtime. If
# it is missing try generating it and re-check. Only fall back to C.UTF-8
# if generation fails.
if ! locale -a | grep -qi "ja_JP\\.utf"; then
  echo "[*] ja_JP.UTF-8 locale not found — attempting to generate it..."
  # Try to generate and install the locale (best-effort)
  sudo locale-gen ja_JP.UTF-8 || true
  sudo update-locale LANG=ja_JP.UTF-8 || true

  # Re-check that the locale is present; only then keep ja_JP; otherwise
  # fall back to C.UTF-8 which still uses UTF-8 encoding.
  if locale -a | grep -qi "ja_JP\\.utf"; then
    echo "[*] ja_JP.UTF-8 locale is now available"
    export LANG=ja_JP.UTF-8
    export LC_ALL=ja_JP.UTF-8
    export LANGUAGE=ja_JP:ja
    export LC_CTYPE=ja_JP.UTF-8
  else
    echo "[!] failed to install ja_JP.UTF-8 — falling back to C.UTF-8"
    export LANG=C.UTF-8
    export LC_ALL=C.UTF-8
    export LANGUAGE=C
    export LC_CTYPE=C.UTF-8
  fi
fi

# Codespaces 等で /run/user/1000 が使えない場合があるため /tmp を利用
export XDG_RUNTIME_DIR="/tmp/run-user-1000"
mkdir -p "$XDG_RUNTIME_DIR"
chown "$(id -u):$(id -g)" "$XDG_RUNTIME_DIR"

# XPRA 起動（Xvfb は先に明示的に起動しておき、xpra には余計な位置引数を渡さない）
# こうすることで xpra が "too many extra arguments" で失敗する問題を回避します。
echo "[*] Starting Xvfb for XPRA display :100..."
# Xvfb を :100 ディスプレイで起動しておく（xpra がこのディスプレイを利用する）
/usr/bin/Xvfb :100 -screen 0 1366x768x24 -dpi 96 +extension RANDR +extension RENDER +extension GLX &
sleep 1
# 起動した Xvfb に XFCE を紐づける（DISPLAY を指定してバックグラウンドで起動）
if ! pgrep -f "startxfce4" >/dev/null 2>&1; then
  echo "[*] Launching XFCE on :100..."
  DISPLAY=:100 startxfce4 > /tmp/startxfce4.log 2>&1 &
  sleep 1
fi

  # Start xpra once (daemon) and wait briefly for the port
xpra stop :100 2>/dev/null || true

# Start xpra once (daemon). Wait briefly for the port to appear.
nohup xpra start :100 \
  --env=LANG=${LANG} \
  --env=LC_ALL=${LC_ALL} \
  --env=LANGUAGE=${LANGUAGE} \
  --env=LC_CTYPE=${LC_CTYPE} \
  --env=PYTHONIOENCODING=${PYTHONIOENCODING} \
  --bind-tcp=0.0.0.0:10000 \
  --html=on \
  --use-display=yes \
  --fake-xinerama=no \
  --mdns=no \
  --encoding=rgb \
  --dpi=96 \
  --resize-display=no \
  --daemon=yes \
  > /tmp/xpra.log 2>&1 &

for i in $(seq 1 5); do
  sleep 0.6
  if ss -ltnp 2>/dev/null | grep -q ':10000\b'; then
    echo "[*] XPRA listening on port 10000"
    break
  fi
  echo "[*] waiting xpra bind (attempt ${i}/5)"
done

sleep 1
# ここでは xpra がサーバーのサイズをクライアントに合わせて変更しないようにしています
# 必要であれば手動で set-window/resize する対処に変更してください。

echo "[*] XPRA started on port 10000"
echo "=============================================================="
echo " • noVNC: /6080/"
echo " • XPRA:  /10000/"
echo " • UI:    /desktop-switcher"
echo "=============================================================="

# Ensure panels stay above (helper keeps xfce4-panel windows set to above)
if [ -x "$PWD/bin/keep-panel-above.sh" ]; then
  echo "[*] Starting keep-panel-above helper (keeps XFCE panels on top)"
  nohup "$PWD/bin/keep-panel-above.sh" > /tmp/keep-panel-above.log 2>&1 &
fi

# Try to disable panel auto-hide / intelligent hide so the panel should
# remain visible in XPRA sessions — perform this as a best-effort using
# xfconf-query. If xfconf-query isn't present or keys differ across versions,
# this will fail silently.
if command -v xfconf-query >/dev/null 2>&1; then
  echo "[*] Applying XFCE panel settings (disable autohide / ensure above)"
  # List keys and try to set any key containing 'autohide' to false
  set +e
  for key in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -i autohide || true); do
    xfconf-query -c xfce4-panel -p "$key" -s false >/dev/null 2>&1 || true
  done
  set -e
fi
