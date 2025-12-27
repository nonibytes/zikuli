#!/bin/bash
#
# Run Zikuli Web Button Test
#
# This script:
# 1. Starts a local HTTP server
# 2. Opens Firefox with the test page
# 3. Runs Zikuli to find and click buttons
# 4. Reports results
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
WEB_DIR="$PROJECT_DIR/tests/web"
PORT=8765

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Zikuli Web Button Test                               ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if we have a display
if [ -z "$DISPLAY" ]; then
    echo -e "${RED}ERROR: No DISPLAY set. Run with Xephyr or real X11.${NC}"
    echo "  Use: ./tests/scripts/run_virtual_tests.sh web-test"
    exit 1
fi

echo -e "${YELLOW}Display: $DISPLAY${NC}"

# Kill any existing server on this port
pkill -f "python.*$PORT" 2>/dev/null || true

# Start HTTP server in background
echo -e "${YELLOW}Starting HTTP server on port $PORT...${NC}"
cd "$WEB_DIR"
python3 -m http.server $PORT &>/dev/null &
HTTP_PID=$!
sleep 1

# Check if server started
if ! kill -0 $HTTP_PID 2>/dev/null; then
    echo -e "${RED}Failed to start HTTP server${NC}"
    exit 1
fi
echo -e "${GREEN}✓ HTTP server started (PID: $HTTP_PID)${NC}"

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}Cleaning up...${NC}"
    kill $HTTP_PID 2>/dev/null || true
    pkill -f "firefox.*$PORT" 2>/dev/null || true
    pkill -f "chromium.*$PORT" 2>/dev/null || true
}
trap cleanup EXIT

# Open browser
BROWSER=""
URL="http://localhost:$PORT/test_page.html"

if command -v firefox &>/dev/null; then
    BROWSER="firefox"
elif command -v chromium-browser &>/dev/null; then
    BROWSER="chromium-browser"
elif command -v chromium &>/dev/null; then
    BROWSER="chromium"
elif command -v google-chrome &>/dev/null; then
    BROWSER="google-chrome"
else
    echo -e "${RED}No browser found (tried: firefox, chromium, chrome)${NC}"
    exit 1
fi

echo -e "${YELLOW}Opening $BROWSER...${NC}"
$BROWSER "$URL" &>/dev/null &
BROWSER_PID=$!

# Wait for browser to load
echo -e "${YELLOW}Waiting for page to load (5 seconds)...${NC}"
sleep 5

# Check if browser is still running
if ! kill -0 $BROWSER_PID 2>/dev/null; then
    echo -e "${RED}Browser failed to start${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Browser started (PID: $BROWSER_PID)${NC}"

# Build and run the test
echo ""
echo -e "${YELLOW}Building and running Zikuli test...${NC}"
cd "$PROJECT_DIR"

# Build the web test binary
if ! ~/.zig/zig build web-test 2>&1; then
    echo -e "${RED}Build failed${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"

# Run the test
./zig-out/bin/web-test

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Test completed!${NC}"
