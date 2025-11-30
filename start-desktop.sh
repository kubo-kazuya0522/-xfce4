#!/usr/bin/env bash
set -e

echo "[*] Installing XFCE4, VNC, noVNC, XPRA..."

sudo apt-get update -y
sudo apt-get upgrade -y

# CJK fonts and rsvg bindings can help with proper Japanese rendering and
# SVG icon handling which XPRA/GTK may rely on when building menus.
sudo apt-get install -y \
  xfce4 xfce4-goodies tightvncserver novnc websockify dbus-x11 \
  x11-xserver-utils xfce4-terminal pulseaudio xpra \
  fonts-noto-cjk gir1.2-rsvg-2.0 librsvg2-2 \
  wmctrl xdotool \
  language-pack-ja language-pack-gnome-ja fonts-ipafont fonts-ipafont-gothic fonts-ipafont-mincho \
  wget tar xz-utils bzip2

# ロケール生成（可能なら）
sudo locale-gen ja_JP.UTF-8 || true
sudo update-locale LANG=ja_JP.UTF-8 || true

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

echo "[*] Starting VNC..."
vncserver :1 -geometry 1366x768 -depth 24

echo "[*] Starting noVNC on port 6080..."
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

echo "[*] Starting PulseAudio..."
pulseaudio --kill 2>/dev/null || true
pulseaudio --start --exit-idle-time=-1

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
echo "[*] Starting Xvfb for XPRA display :100 (1366x768, 96dpi)..."
# Xvfb を :100 ディスプレイで起動しておく（xpra がこのディスプレイを利用する）
/usr/bin/Xvfb :100 -screen 0 1366x768x24 -dpi 96 +extension RANDR +extension RENDER +extension GLX &
sleep 1
# 起動した Xvfb に XFCE を紐づける（DISPLAY を指定してバックグラウンドで起動）
if ! pgrep -f "startxfce4" >/dev/null 2>&1; then
  echo "[*] Launching XFCE on :100..."
  DISPLAY=:100 startxfce4 > /tmp/startxfce4.log 2>&1 &
  sleep 3
fi

  # (xpra arguments are supplied/managed by the supervisor below)
# Run xpra with a simple supervisor: if the server stops (e.g. a client
# requested shutdown), automatically restart it with exponential backoff.
start_xpra_and_supervise() {
  local max_restarts=6
  local attempt=0
  local backoff=1
  while true; do
    attempt=$((attempt+1))
    echo "[*] Starting xpra (attempt ${attempt})..." >> /tmp/xpra-supervisor.log
    # make sure any previous instance is gone
    xpra stop :100 >/dev/null 2>&1 || true

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

    # Wait up to 10 seconds for the port to appear
    local waited=0
    while [ $waited -lt 10 ]; do
      sleep 1
      waited=$((waited+1))
      if ss -ltnp 2>/dev/null | grep -q ':10000\b'; then
        echo "[*] xpra listening on port 10000 (supervised)" >> /tmp/xpra-supervisor.log
        break
      fi
    done

    # Wait until xpra stops (detect by checking process that owns port 10000)
    while ss -ltnp 2>/dev/null | grep -q ':10000\b'; do
      sleep 2
    done

    echo "[!] xpra exited; dumping last logs to /tmp/xpra-supervisor.log" >> /tmp/xpra-supervisor.log
    tail -n 200 /tmp/xpra.log >> /tmp/xpra-supervisor.log 2>/dev/null || true

    # Backoff and then restart unless we've retried too many times
    if [ $attempt -ge $max_restarts ]; then
      echo "[!] xpra restart failed after ${attempt} attempts, sleeping longer" >> /tmp/xpra-supervisor.log
      sleep 30
      attempt=0
      backoff=1
    else
      sleep $backoff
      backoff=$((backoff * 2))
      if [ $backoff -gt 60 ]; then backoff=60; fi
    fi
  done
}

# Launch supervisor in background so script continues
start_xpra_and_supervise &

# Wait for xpra to open the TCP port. If it never appears, dump logs
# for easier debugging (helps catch "too many extra arguments" or
# permission/encoding issues introduced during edits).
for i in $(seq 1 8); do
  sleep 1
  if ss -ltnp 2>/dev/null | grep -q ':10000\b'; then
    echo "[*] XPRA listening on port 10000"
    break
  fi
  echo "[*] Waiting for XPRA to bind port 10000 (attempt ${i}/8)..."
  if [ $i -eq 8 ]; then
    echo "[!] XPRA failed to bind port 10000; dumping logs for debugging"
    echo "---- /tmp/xpra.log (tail -n 200) ----"
    tail -n 200 /tmp/xpra.log || true
    echo "---- /run/user/$(id -u)/xpra/:100.log (tail -n 200) ----"
    tail -n 200 /run/user/$(id -u)/xpra/:100.log || true
  fi
done

sleep 5
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
