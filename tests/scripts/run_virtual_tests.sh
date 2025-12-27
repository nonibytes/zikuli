#!/bin/bash
# run_virtual_tests.sh - Run Zikuli tests in virtual X11 environment
#
# Usage:
#   ./run_virtual_tests.sh              # Run all tests
#   ./run_virtual_tests.sh test_finder  # Run specific test
#
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
DISPLAY_NUM=99
SCREEN_WIDTH=${SCREEN_WIDTH:-1920}
SCREEN_HEIGHT=${SCREEN_HEIGHT:-1080}
SCREEN_DEPTH=24

echo "=== Zikuli Virtual Test Environment ==="
echo "Resolution: ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH}"
echo "Project: $PROJECT_ROOT"
echo ""

# Check for Xvfb
if ! command -v Xvfb &> /dev/null; then
    echo "ERROR: Xvfb not found. Install with: sudo apt-get install xvfb"
    exit 1
fi

# Cleanup any existing Xvfb on our display
cleanup() {
    echo "Cleaning up..."
    pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
}
trap cleanup EXIT

# Kill existing Xvfb if running
pkill -f "Xvfb :${DISPLAY_NUM}" 2>/dev/null || true
sleep 0.2

# Start Xvfb
echo "Starting Xvfb on display :${DISPLAY_NUM}..."
Xvfb :${DISPLAY_NUM} -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH} -ac -nolisten tcp &
XVFB_PID=$!
sleep 0.5

# Verify Xvfb is running
if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo "ERROR: Xvfb failed to start"
    exit 1
fi
echo "Xvfb started (PID: $XVFB_PID)"

# Set display
export DISPLAY=:${DISPLAY_NUM}

# Verify display works
if ! xdpyinfo &>/dev/null; then
    echo "ERROR: Cannot connect to display :${DISPLAY_NUM}"
    exit 1
fi

SCREEN_INFO=$(xdpyinfo | grep "dimensions:" | awk '{print $2}')
echo "Display verified: $SCREEN_INFO"
echo ""

# Reset environment
echo "Resetting test environment..."
xdotool mousemove --sync 0 0 2>/dev/null || true

# Run tests
echo "Running tests..."
cd "$PROJECT_ROOT"

if [ -n "$1" ]; then
    # Run specific test
    echo "Running: $1"
    ~/.zig/zig build "$1"
    TEST_RESULT=$?
else
    # Run all tests
    ~/.zig/zig build test
    TEST_RESULT=$?
fi

echo ""
if [ $TEST_RESULT -eq 0 ]; then
    echo "=== All tests PASSED ==="
else
    echo "=== Tests FAILED (exit code: $TEST_RESULT) ==="
fi

exit $TEST_RESULT
