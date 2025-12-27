#!/bin/bash
# debug_visual.sh - Run tests in visible Xephyr window for debugging
#
# Usage:
#   ./debug_visual.sh                    # Interactive mode
#   ./debug_visual.sh test-virtual       # Run specific test
#   ./debug_visual.sh --watch            # Keep running and watch
#   SLOW=1 ./debug_visual.sh test-virtual # Slow mode to see steps
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DISPLAY_NUM=99
SCREEN_WIDTH=${SCREEN_WIDTH:-1920}
SCREEN_HEIGHT=${SCREEN_HEIGHT:-1080}

echo "╔════════════════════════════════════════════╗"
echo "║   Zikuli Visual Debug Environment         ║"
echo "╠════════════════════════════════════════════╣"
echo "║ Resolution: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}"
echo "║ Display:    :${DISPLAY_NUM}"
echo "╚════════════════════════════════════════════╝"
echo ""

# Check for Xephyr
if ! command -v Xephyr &> /dev/null; then
    echo "ERROR: Xephyr not found. Install with:"
    echo "  sudo apt-get install xserver-xephyr"
    exit 1
fi

# Cleanup
cleanup() {
    echo ""
    echo "Cleaning up..."
    pkill -f "Xephyr :${DISPLAY_NUM}" 2>/dev/null || true
}
trap cleanup EXIT

# Kill existing
pkill -f "Xephyr :${DISPLAY_NUM}" 2>/dev/null || true
rm -f /tmp/.X${DISPLAY_NUM}-lock 2>/dev/null || true
sleep 0.3

# Start Xephyr (visible window)
echo "Starting Xephyr window..."
Xephyr :${DISPLAY_NUM} \
    -screen ${SCREEN_WIDTH}x${SCREEN_HEIGHT} \
    -title "Zikuli Debug - :${DISPLAY_NUM}" \
    -retro \
    -host-cursor &
XEPHYR_PID=$!
sleep 1

if ! kill -0 $XEPHYR_PID 2>/dev/null; then
    echo "ERROR: Xephyr failed to start"
    exit 1
fi
echo "✓ Xephyr started (PID: $XEPHYR_PID)"

export DISPLAY=:${DISPLAY_NUM}

# Verify display
if ! xdpyinfo &>/dev/null; then
    echo "ERROR: Cannot connect to Xephyr"
    exit 1
fi
echo "✓ Display verified: $(xdpyinfo | grep dimensions | awk '{print $2}')"
echo ""

cd "$PROJECT_ROOT"

# Set slower execution if SLOW mode requested
if [ -n "$SLOW" ]; then
    export ZIKULI_TEST_DELAY=500  # 500ms delay between operations
    echo "SLOW MODE: Adding delays between operations"
fi

if [ "$1" = "--watch" ]; then
    # Watch mode - keep running
    echo "WATCH MODE: Xephyr window will stay open."
    echo ""
    echo "In another terminal, run commands like:"
    echo "  export DISPLAY=:${DISPLAY_NUM}"
    echo "  ~/.zig/zig build test-virtual"
    echo "  ./zig-out/bin/zikuli capture -o /tmp/screen.png"
    echo "  ./zig-out/bin/zikuli click 100 100"
    echo ""
    echo "Press Ctrl+C to close Xephyr..."
    while true; do
        sleep 1
    done
elif [ -n "$1" ]; then
    # Run specific test
    echo "Running: $1"
    echo "════════════════════════════════════════════"
    ~/.zig/zig build "$1" 2>&1
    echo "════════════════════════════════════════════"
    echo ""
    echo "Test complete. Press Enter to close, or Ctrl+C to keep Xephyr open..."
    read
else
    echo "INTERACTIVE MODE"
    echo ""
    echo "Xephyr window is ready. Commands to try:"
    echo ""
    echo "  # Capture screenshot"
    echo "  DISPLAY=:${DISPLAY_NUM} ./zig-out/bin/zikuli capture -o /tmp/test.png"
    echo ""
    echo "  # Run virtual tests"
    echo "  DISPLAY=:${DISPLAY_NUM} ~/.zig/zig build test-virtual"
    echo ""
    echo "  # Move mouse"
    echo "  DISPLAY=:${DISPLAY_NUM} ./zig-out/bin/zikuli move 500 300"
    echo ""
    echo "  # Click"
    echo "  DISPLAY=:${DISPLAY_NUM} ./zig-out/bin/zikuli click 500 300"
    echo ""
    echo "Press Enter to close Xephyr, or Ctrl+C to keep it running..."
    read
fi
