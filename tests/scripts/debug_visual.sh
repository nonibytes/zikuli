#!/bin/bash
# debug_visual.sh - Run tests in visible Xephyr window for debugging
#
# Usage:
#   ./debug_visual.sh              # Interactive mode
#   ./debug_visual.sh test_finder  # Run specific test
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DISPLAY_NUM=99
SCREEN_WIDTH=${SCREEN_WIDTH:-1280}
SCREEN_HEIGHT=${SCREEN_HEIGHT:-720}

echo "=== Zikuli Visual Debug Environment ==="
echo "Resolution: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"

# Check for Xephyr
if ! command -v Xephyr &> /dev/null; then
    echo "ERROR: Xephyr not found. Install with: sudo apt-get install xserver-xephyr"
    exit 1
fi

# Cleanup
cleanup() {
    echo "Cleaning up..."
    pkill -f "Xephyr :${DISPLAY_NUM}" 2>/dev/null || true
}
trap cleanup EXIT

# Kill existing
pkill -f "Xephyr :${DISPLAY_NUM}" 2>/dev/null || true
sleep 0.2

# Start Xephyr (visible window)
echo "Starting Xephyr..."
Xephyr :${DISPLAY_NUM} -screen ${SCREEN_WIDTH}x${SCREEN_HEIGHT} -title "Zikuli Debug" &
XEPHYR_PID=$!
sleep 1

if ! kill -0 $XEPHYR_PID 2>/dev/null; then
    echo "ERROR: Xephyr failed to start"
    exit 1
fi
echo "Xephyr started (PID: $XEPHYR_PID)"

export DISPLAY=:${DISPLAY_NUM}

# Verify
xdpyinfo &>/dev/null || { echo "ERROR: Cannot connect to Xephyr"; exit 1; }

cd "$PROJECT_ROOT"

if [ -n "$1" ]; then
    # Run specific test
    echo "Running: $1"
    ~/.zig/zig build "$1"
else
    echo ""
    echo "Xephyr window is ready. You can now run commands like:"
    echo "  DISPLAY=:${DISPLAY_NUM} ./zig-out/bin/zikuli capture -o /tmp/test.png"
    echo "  DISPLAY=:${DISPLAY_NUM} ~/.zig/zig build test"
    echo ""
    echo "Press Enter to close Xephyr, or Ctrl+C to keep it running..."
    read
fi
