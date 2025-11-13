#!/usr/bin/env bash
set -e

# === 環境準備 ============================================================
echo "[*] Installing XFCE4, VNC, and noVNC..."
sudo apt-get update -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    xfce4 xfce4-goodies tightvncserver novnc websockify dbus-x11 \
    x11-xserver-utils xfce4-terminal firefox language-pack-ja language-pack-gnome-ja

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

echo ""
echo "=============================================================="
echo "✅ XFCE4 Desktop is running!"
echo "   • Connect via your Codespaces 'Ports' tab (port 6080 → Public)"
echo "   • Then open it in browser."
echo "   • VNC password: vncpass"
echo "=============================================================="
echo ""
