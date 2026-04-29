#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Browser stack startup — Xvfb + Chrome (CDP) + x11vnc + noVNC
# ─────────────────────────────────────────────────────────────────────────────
# Access:
#   noVNC (browser):  http://localhost:6080/vnc.html
#   CDP (programmatic): ws://localhost:9222
#   VNC (desktop app): vnc://localhost:5900
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

BROWSER_PROFILE_DIR="${BROWSER_PROFILE_DIR:-/browser-profile}"
RESOLUTION="${BROWSER_RESOLUTION:-1920x1080}"
CDP_PORT="${CDP_PORT:-9222}"
VNC_PORT="${VNC_PORT:-5900}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

# Ensure profile directory exists
mkdir -p "$BROWSER_PROFILE_DIR"

echo "=== Browser Stack ==="
echo "  Profile dir : $BROWSER_PROFILE_DIR"
echo "  Resolution  : $RESOLUTION"
echo "  CDP port    : $CDP_PORT"
echo "  VNC port    : $VNC_PORT"
echo "  noVNC port  : $NOVNC_PORT"

# ── 1. Xvfb (virtual display) ───────────────────────────────────────────────
echo "[browser] Starting Xvfb on :99 ..."
Xvfb :99 -screen 0 "${RESOLUTION}x24" -ac +extension GLX +render -noreset &
XVFB_PID=$!
sleep 1
export DISPLAY=:99

# ── 2. Chrome with remote debugging ─────────────────────────────────────────
echo "[browser] Starting Chrome with CDP on port $CDP_PORT ..."
google-chrome \
    --remote-debugging-address=0.0.0.0 \
    --remote-debugging-port="$CDP_PORT" \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --user-data-dir="$BROWSER_PROFILE_DIR" \
    --headless=new \
    --window-size="${RESOLUTION#*x}" \
    "$@" &
CHROME_PID=$!

# ── 3. x11vnc (VNC server — shares X display) ──────────────────────────────
echo "[browser] Starting x11vnc on port $VNC_PORT ..."
x11vnc -display :99 \
       -forever \
       -shared \
       -rfbport "$VNC_PORT" \
       -bg \
       -nopw

# ── 4. noVNC websocket proxy ────────────────────────────────────────────────
echo "[browser] Starting noVNC proxy on port $NOVNC_PORT ..."
websockify \
    --web="/usr/share/novnc" \
    0.0.0.0:"$NOVNC_PORT" \
    localhost:"$VNC_PORT" &

sleep 2

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "=== Browser ready ==="
echo "  noVNC : http://localhost:$NOVNC_PORT/vnc.html"
echo "  CDP   : ws://localhost:$CDP_PORT"
echo "  VNC   : vnc://localhost:$VNC_PORT"
echo ""
echo "Press Ctrl+C to stop all services."

# Wait and clean up on exit
trap 'echo "[browser] Shutting down..."; kill $XVFB_PID $CHROME_PID 2>/dev/null; pkill -f websockify 2>/dev/null; pkill -f x11vnc 2>/dev/null; echo "[browser] Done."' EXIT

wait
