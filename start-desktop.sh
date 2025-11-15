#!/usr/bin/env bash
set -e

echo "[*] Installing XFCE4, VNC, noVNC, XPRA..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify \
    dbus-x11 pulseaudio xpra \
    x11-xserver-utils xfce4-terminal firefox-esr

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

echo "[*] Starting VNC..."
vncserver :1 -geometry 1920x1080 -depth 24

echo "[*] Starting noVNC on port 6080..."
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 \
  > /tmp/novnc.log 2>&1 &

echo "[*] Starting PulseAudio..."
pulseaudio --kill 2>/dev/null || true
pulseaudio --start --exit-idle-time=-1

echo "[*] Starting XPRA..."
nohup xpra start :100 \
    --start-child="dbus-launch xfce4-session" \
    --bind-tcp=0.0.0.0:10000 \
    --html=on \
    --speaker=on \
    --audio-codec=opus \
    --pulseaudio=yes \
    --video-encoders=vp8,vp9 \
    --no-daemon \
    > /tmp/xpra.log 2>&1 &

# === UI Server ======================================================
echo "[*] Starting Desktop Switcher UI on port 8888..."
node ui-server.js &
echo "UI available at -> http://localhost:8888/desktop-switcher"

echo "=============================================================="
echo " • noVNC:   /6080/"
echo " • XPRA:    /10000/"
echo " • UI:      /desktop-switcher"
echo "=============================================================="
