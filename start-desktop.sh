#!/usr/bin/env bash
set -e

echo "[*] Installing XFCE4, VNC, noVNC, XPRA..."

sudo apt-get update -y
sudo apt-get upgrade -y

sudo apt-get install -y \
  xfce4 xfce4-goodies tightvncserver novnc websockify dbus-x11 \
  x11-xserver-utils xfce4-terminal pulseaudio xpra \
  language-pack-ja language-pack-gnome-ja fonts-ipafont fonts-ipafont-gothic fonts-ipafont-mincho \
  wget tar xz-utils bzip2

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

export LANG=ja_JP.UTF-8
export LC_ALL=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja

export XDG_RUNTIME_DIR="/run/user/1000"
sudo mkdir -p /run/user/1000
sudo chown "$USER":"$USER" /run/user/1000

nohup xpra start :100 \
  --bind-tcp=0.0.0.0:10000 \
  --html=on \
  --start="startxfce4" \
  --encoding=vp9 \
  --dpi=96 \
  --xvfb="/usr/bin/Xvfb +extension RANDR +extension RENDER +extension GLX -screen 0 1366x768x24" \
  --daemon=yes \
  > /tmp/xpra.log 2>&1 &

sleep 5

# 初期サイズ適用
xpra control :100 set-resolution 1366x768 || true

echo "[*] XPRA started on port 10000"
echo "=============================================================="
echo " • noVNC: /6080/"
echo " • XPRA:  /10000/"
echo " • UI:    /desktop-switcher"
echo "=============================================================="
