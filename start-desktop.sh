#!/usr/bin/env bash
set -e

# === 画面解像度設定（Chromebook 300e） ================================
SCREEN_WIDTH=1366
SCREEN_HEIGHT=768
DEPTH=24
VNC_DISPLAY=:1
XPRA_DISPLAY=:100
XPRA_PORT=10000
NOVNC_PORT=6080
VNC_PASSWORD="vncpass"

# === 環境準備 ============================================================
echo "[*] Updating system..."
sudo apt-get update -y
sudo apt-get upgrade -y

echo "[*] Installing XFCE4, VNC, noVNC, XPRA, and Japanese fonts..."
sudo apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify dbus-x11 \
    x11-xserver-utils xfce4-terminal pulseaudio xpra \
    language-pack-ja language-pack-gnome-ja fonts-ipafont fonts-ipafont-gothic fonts-ipafont-mincho \
    wget tar bzip2 xz-utils

# === 日本語ロケール =====================================================
sudo locale-gen ja_JP.UTF-8
sudo update-locale LANG=ja_JP.UTF-8 LANGUAGE=ja_JP:ja
export LANG=ja_JP.UTF-8

# === VNC セットアップ ====================================================
VNC_DIR="$HOME/.vnc"
mkdir -p "$VNC_DIR"

if [ ! -f "$VNC_DIR/passwd" ]; then
    echo "[*] Setting VNC password..."
    echo "$VNC_PASSWORD" | vncpasswd -f > "$VNC_DIR/passwd"
    chmod 600 "$VNC_DIR/passwd"
fi

cat > "$VNC_DIR/xstartup" <<'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF
chmod +x "$VNC_DIR/xstartup"

# === 既存VNCセッション停止 ==============================================
if pgrep Xtightvnc >/dev/null; then
    echo "[*] Stopping existing VNC session..."
    vncserver -kill $VNC_DISPLAY || true
fi

# === 新しいVNCサーバー起動 ==============================================
echo "[*] Starting VNC server..."
vncserver $VNC_DISPLAY -geometry ${SCREEN_WIDTH}x${SCREEN_HEIGHT} -depth $DEPTH

# === noVNC 起動 ==========================================================
echo "[*] Starting noVNC on port $NOVNC_PORT..."
nohup websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:5901 > /tmp/novnc.log 2>&1 &

# === Firefox インストール（APT 不使用） =================================
if ! command -v firefox >/dev/null 2>&1; then
    echo "[*] Installing Firefox (direct download)..."
    TMPDIR=$(mktemp -d)
    cd $TMPDIR
    wget -O firefox.tar.xz "https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=ja"
    tar -xf firefox.tar.xz
    sudo mv firefox /opt/firefox
    sudo ln -sf /opt/firefox/firefox /usr/local/bin/firefox
    cd -
    rm -rf $TMPDIR
fi

# === XPRA 起動 ==========================================================
XPRA_LOG="/tmp/xpra.log"
echo "[*] Starting XPRA server on port $XPRA_PORT..."
pulseaudio --start || true

nohup xpra start $XPRA_DISPLAY \
    --start-child="xfce4-session" \
    --bind-tcp=0.0.0.0:$XPRA_PORT \
    --html=on \
    --speaker=on \
    --geometry ${SCREEN_WIDTH}x${SCREEN_HEIGHT} \
    --dpi=96 \
    > $XPRA_LOG 2>&1 &

# === 完了メッセージ ======================================================
echo ""
echo "=============================================================="
echo "✅ XFCE4 Desktop is running!"
echo "   • noVNC: http://<chromebook-ip>:$NOVNC_PORT (ブラウザ)"
echo "   • XPRA: http://<chromebook-ip>:$XPRA_PORT (HTML5 またはネイティブクライアント)"
echo "   • VNC password: $VNC_PASSWORD"
echo "   • XPRA log: $XPRA_LOG"
echo "=============================================================="
echo ""
echo "[*] You can monitor XPRA log using: tail -f $XPRA_LOG"
