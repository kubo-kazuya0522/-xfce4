#!/usr/bin/env bash
set -euo pipefail

# keep xfce4-panel windows set to _NET_WM_STATE_ABOVE so panels stay on top
# Works by scanning for windows named "xfce4-panel" on the configured DISPLAY
# and forcing the _NET_WM_STATE to include _NET_WM_STATE_ABOVE. We also try
# to use wmctrl / xdotool as a fallback to raise/force 'above'. Run in
# background. This is a best-effort helper used in XPRA sessions where the
# panel may otherwise be pushed behind other windows.

export DISPLAY=${DISPLAY:-:100}

has() { command -v "$1" >/dev/null 2>&1; }

echo "[*] keep-panel-above helper started (DISPLAY=$DISPLAY)"

while true; do
  # Prefer wmctrl if available (prints window id first column)
  if has wmctrl; then
    ids=$(wmctrl -l -x 2>/dev/null | awk '/xfce4-panel/ { print $1 }' || true)
  else
    # Fallback to xwininfo parsing
    ids=$(xwininfo -root -tree 2>/dev/null | awk '/xfce4-panel/ { print $1 }' || true)
  fi

  for id in $ids; do
    if [ -z "$id" ]; then
      continue
    fi

    # Try several mechanisms to keep the panel above other windows
    # 1) _NET_WM_STATE_ABOVE via xprop
    xprop -id "$id" -f _NET_WM_STATE 32a -set _NET_WM_STATE _NET_WM_STATE_ABOVE >/dev/null 2>&1 || true

    # 2) wmctrl add,above
    if has wmctrl; then
      wmctrl -i -r "$id" -b add,above >/dev/null 2>&1 || true
    fi

    # 3) xdotool windowraise
    if has xdotool; then
      xdotool windowraise "$id" >/dev/null 2>&1 || true
    fi
  done

  # Best-effort: disable any autohide flags in xfce4-panel via xfconf
  if has xfconf-query; then
    for key in $(xfconf-query -c xfce4-panel -l 2>/dev/null | grep -i autohide || true); do
      xfconf-query -c xfce4-panel -p "$key" -s false >/dev/null 2>&1 || true
    done
  fi

  sleep 1
done
