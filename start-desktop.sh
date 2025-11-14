#!/usr/bin/env bash
set -e

echo "[*] Installing XFCE4, VNC, noVNC, XPRA..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify \
    dbus-x11 pulseaudio xpra \
    x11-xserver-utils xfce4-terminal firefox \
    language-pack-ja language-pack-gnome-ja

# === Locale =========================================================
sudo locale-gen ja_JP.UTF-8
sudo update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
export LANG=ja_JP.UTF-8

# === VNC Setup ======================================================
VNC_DIR="$HOME/.vnc"
mkdir -p "$VNC_DIR"

if [ ! -f "$VNC_DIR/passwd" ]; then
  echo "vncpass" | vncpasswd -f > "$VNC_DIR/passwd"
  chmod 600 "$VNC_DIR/passwd"
fi

cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
dbus-launch startxfce4 &
EOF
chmod +x "$VNC_DIR/xstartup"

# === Stop previous sessions ========================================
vncserver -kill :1 2>/dev/null || true
xpra stop :100 2>/dev/null || true

# === Start VNC ======================================================
echo "[*] Starting VNC..."
vncserver :1 -geometry 1920x1080 -depth 24

echo "[*] Starting noVNC on port 6080..."
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 \
  > /tmp/novnc.log 2>&1 &

# === Start PulseAudio ==============================================
echo "[*] Starting PulseAudio..."
pulseaudio --kill 2>/dev/null || true
pulseaudio --start --exit-idle-time=-1

# === Start XPRA ====================================================
echo "[*] Starting XPRA on port 10000..."

nohup xpra start :100 \
    --start-child="dbus-launch xfce4-session" \
    --bind-tcp=0.0.0.0:10000 \
    --html=on \
    --speaker=on \
    --microphone=off \
    --video-encoders=vp8,vp9 \
    --audio-codec=opus \
    --pulseaudio=yes \
    --no-daemon \
    > /tmp/xpra.log 2>&1 &

echo "=============================================================="
echo " XFCE Desktop Ready!"
echo " • noVNC: port 6080 → public"
echo " • XPRA HTML5 client: port 10000 → public"
echo "   (Audio OK through XPRA)"
echo "   (VNC/noVNC は音声非対応)"
echo "=============================================================="
