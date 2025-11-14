#!/usr/bin/env bash
set -e

echo "[*] Updating system..."
sudo apt-get update -y

echo "[*] Installing XFCE4, VNC, noVNC, XPRA..."
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify \
    dbus-x11 pulseaudio xpra \
    x11-xserver-utils xfce4-terminal fonts-ipafont \
    language-pack-ja language-pack-gnome-ja wget tar

# ============================================================
# Firefox DEB を Mozilla サイトから直接ダウンロード
# ============================================================
echo "[*] Installing Firefox (direct DEB download)..."
TMPDIR=$(mktemp -d)
cd $TMPDIR

# 最新安定版 Firefox の URL を取得
FIREFOX_URL=$(curl -s https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=ja)

wget -O firefox.tar.bz2 "$FIREFOX_URL"
tar xjf firefox.tar.bz2
sudo mv firefox /opt/firefox
sudo ln -sf /opt/firefox/firefox /usr/local/bin/firefox

cd -
rm -rf $TMPDIR

# ============================================================
# 日本語ロケール
# ============================================================
echo "[*] Configuring Japanese locale..."
sudo locale-gen ja_JP.UTF-8
sudo update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
export LANG=ja_JP.UTF-8

cat <<EOF > ~/.xsessionrc
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
EOF

grep -q "LANG=ja_JP.UTF-8" ~/.bashrc || cat <<EOF >> ~/.bashrc
export LANG=ja_JP.UTF-8
export LANGUAGE=ja_JP:ja
export LC_ALL=ja_JP.UTF-8
EOF

# ============================================================
# VNC セットアップ
# ============================================================
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
vncserver :1 -geometry 1920x1080 -depth 24
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

# ============================================================
# PulseAudio
# ============================================================
pulseaudio --kill 2>/dev/null || true
pulseaudio --start --exit-idle-time=-1

# ============================================================
# XPRA（音声つき）
# ============================================================
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
echo " • XPRA (Audio Enabled): http://localhost:10000/"
echo " • noVNC: http://localhost:6080/"
echo " • VNC password: vncpass"
echo "=============================================================="
