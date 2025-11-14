#!/usr/bin/env bash
set -e

# === 環境準備 ============================================================
echo "[*] Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "[*] Installing XFCE4, VNC, noVNC, XPRA, and Japanese fonts..."
sudo apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify dbus-x11 \
    x11-xserver-utils xfce4-terminal pulseaudio xpra \
    language-pack-ja language-pack-gnome-ja fonts-ipafont fonts-ipafont-gothic fonts-ipafont-mincho wget tar bzip2

# === 日本語ロケール =====================================================
sudo locale-gen ja_JP.UTF-8
sudo update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
export LANG=ja_JP.UTF-8

# === VNC セットアップ ====================================================
VNC_DIR="$HOME/.vnc"
mkdir -p "$VNC_DIR"

if [ ! -f "$VNC_DIR/passwd" ]; then
  echo "[*] Setting VNC password..."
  echo "vncpass" | vncpasswd -f > "$VNC_DIR/passwd"
  chmod 600 "$VNC_DIR/passwd"
fi

cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x "$VNC_DIR/xstartup"

# === 既存VNCセッション停止 ==============================================
if pgrep Xtightvnc > /dev/null; then
  echo "[*] Stopping existing VNC session..."
  vncserver -kill :1 || true
fi

# === 新しいVNCサーバー起動 ==============================================
echo "[*] Starting VNC server..."
vncserver :1 -geometry 1920x1080 -depth 24

# === noVNC 起動 ==========================================================
echo "[*] Starting noVNC on port 6080..."
nohup websockify --web=/usr/share/novnc/ 6080 localhost:5901 > /tmp/novnc.log 2>&1 &

# === Firefox インストール（APT 不使用） =================================
if ! command -v firefox >/dev/null 2>&1; then
  echo "[*] Installing Firefox (direct download)..."
  TMPDIR=$(mktemp -d)
  cd $TMPDIR
  wget -O firefox.tar.bz2 "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=ja"
  tar xjf firefox.tar.bz2
  sudo mv firefox /opt/firefox
  sudo ln -sf /opt/firefox/firefox /usr/local/bin/firefox
  cd -
  rm -rf $TMPDIR
fi

# === XPRA 起動 ==========================================================
echo "[*] Starting XPRA server on port 10000..."
pulseaudio --start

nohup xpra start :100 \
    --start-child="xfce4-session" \
    --bind-tcp=0.0.0.0:10000 \
    --html=on \
    --speaker=on \
    --screen=1920x1080 \
    > /tmp/xpra.log 2>&1 &

echo ""
echo "=============================================================="
echo "✅ XFCE4 Desktop is running!"
echo "   • noVNC: Connect via port 6080 (browser)"
echo "   • XPRA: Connect via port 10000 (HTML5 or native client)"
echo "   • VNC password: vncpass"
echo "=============================================================="
echo ""
