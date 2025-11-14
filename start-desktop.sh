#!/usr/bin/env bash
set -e

echo "[*] Updating system..."
sudo apt-get update -y

echo "[*] Installing desktop packages..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify \
    dbus-x11 pulseaudio xpra \
    x11-xserver-utils xfce4-terminal firefox-esr \
    language-pack-ja language-pack-gnome-ja fonts-ipafont

# ============================================================
# 日本語ロケール設定
# ============================================================
echo "[*] Configuring Japanese locale..."
sudo locale-gen ja_JP.UTF-8
sudo update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
export LANG=ja_JP.UTF-8

# ~/.xsessionrc（XFCE 用）
cat <<EOF > ~/.xsessionrc
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
EOF

# ~/.bashrc（ターミナル用）
grep -q "LANG=ja_JP.UTF-8" ~/.bashrc || cat <<EOF >> ~/.bashrc
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
EOF

# ============================================================
# VNC セットアップ
# ============================================================
echo "[*] Setting up VNC..."
mkdir -p ~/.vnc

echo "vncpass" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnc/passwd

cat <<EOF > ~/.vnc/xstartup
#!/bin/bash
xrdb \$HOME/.Xresources
dbus-launch startxfce4 &
EOF
chmod +x ~/.vnc/xstartup

vncserver -kill :1 2>/dev/null || true

echo "[*] Starting VNC server..."
vncserver :1 -geometry 1920x1080 -depth 24

echo "[*] Starting noVNC on port 6080..."
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

# ============================================================
# PulseAudio
# ============================================================
echo "[*] Starting PulseAudio..."
pulseaudio --kill 2>/dev/null || true
pulseaudio --start --exit-idle-time=-1

# ============================================================
# XPRA（HTML5 + 音声 + フルHD）
# ============================================================
echo "[*] Starting XPRA... (port 10000)"
xpra stop :100 2>/dev/null || true

nohup xpra start :100 \
    --start-child="dbus-launch xfce4-session" \
    --bind-tcp=0.0.0.0:10000 \
    --html=on \
    --encoding=vp9 \
    --sound=yes \
    --sound-source=pulseaudio \
    --virtual-resolution=1920x1080 \
    --resize-display=yes \
    --dpi=96 \
    --no-daemon \
    > /tmp/xpra.log 2>&1 &

echo ""
echo "=============================================================="
echo " 🚀 XFCE4 Desktop Ready!"
echo " • XPRA (with audio): http://localhost:10000/"
echo " • noVNC (VNC): http://localhost:6080/"
echo " • VNC password: vncpass"
echo "=============================================================="
