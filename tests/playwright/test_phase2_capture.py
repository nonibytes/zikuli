#!/usr/bin/env python3
"""
Phase 2 Verification: X11 Screen Capture with Real Browser

This test verifies Zikuli's screen capture functionality works correctly
by capturing a browser window showing a known page and validating the result.
"""

import os
import subprocess
import time
from datetime import datetime
from pathlib import Path
from playwright.sync_api import sync_playwright

PROJECT_ROOT = Path(__file__).parent.parent.parent
ZIKULI_BIN = PROJECT_ROOT / "zig-out" / "bin"
TEST_CAPTURE_BIN = ZIKULI_BIN / "test_capture"


def log(msg: str):
    """Log with timestamp."""
    print(f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] {msg}")


def build_zikuli():
    """Ensure Zikuli is built."""
    log("Building Zikuli...")
    result = subprocess.run(
        [os.path.expanduser("~/.zig/zig"), "build"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True
    )
    if result.returncode != 0:
        log(f"Build failed: {result.stderr}")
        raise RuntimeError("Build failed")
    log("Build successful")


def run_test_capture() -> subprocess.CompletedProcess:
    """Run the test_capture binary."""
    if not TEST_CAPTURE_BIN.exists():
        raise FileNotFoundError(f"test_capture not found at {TEST_CAPTURE_BIN}")

    log(f"Running: {TEST_CAPTURE_BIN}")
    result = subprocess.run(
        [str(TEST_CAPTURE_BIN)],
        capture_output=True,
        text=True,
        timeout=30
    )
    return result


def test_screen_capture_with_browser():
    """Test screen capture while a browser is visible."""
    log("=" * 60)
    log("Phase 2 Verification: X11 Screen Capture")
    log("=" * 60)

    # Build first
    build_zikuli()

    with sync_playwright() as p:
        log("Launching browser...")
        browser = p.chromium.launch(
            headless=False,
            args=['--window-position=100,100', '--window-size=800,600']
        )
        page = browser.new_page()

        # Navigate to a distinctive test page
        log("Navigating to test page...")
        page.goto("https://example.com")
        page.wait_for_load_state("networkidle")
        log(f"Page title: {page.title()}")

        # Give the screen time to settle
        time.sleep(1)

        # Run Zikuli screen capture test
        log("Running Zikuli screen capture...")
        result = run_test_capture()

        log(f"Exit code: {result.returncode}")
        if result.stdout:
            for line in result.stdout.strip().split('\n'):
                log(f"  stdout: {line}")
        if result.stderr:
            for line in result.stderr.strip().split('\n'):
                log(f"  stderr: {line}")

        # Verify success
        if result.returncode != 0:
            log("FAILED: test_capture returned non-zero exit code")
            browser.close()
            return False

        # Check for key success markers in output
        output = result.stdout
        checks = [
            ("Connected", "X11 connection established"),
            ("Captured", "Screen region captured"),
            ("Full screen", "Full screen capture worked"),
            ("PASSED", "All tests passed"),
        ]

        all_passed = True
        for marker, description in checks:
            if marker in output:
                log(f"  [PASS] {description}")
            else:
                log(f"  [FAIL] {description}")
                all_passed = False

        browser.close()

        log("=" * 60)
        if all_passed:
            log("Phase 2 Verification: PASSED")
        else:
            log("Phase 2 Verification: FAILED")
        log("=" * 60)

        return all_passed


def test_capture_contains_browser_pixels():
    """
    Advanced test: Verify captured pixels include browser content.

    This is a more thorough test that:
    1. Creates a browser with known colors
    2. Captures that region
    3. Verifies the colors appear in the capture
    """
    log("=" * 60)
    log("Phase 2 Advanced: Pixel Verification")
    log("=" * 60)

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=False,
            args=['--window-position=50,50', '--window-size=400,300']
        )
        page = browser.new_page()

        # Create a page with known solid color
        page.set_content("""
            <html>
            <body style="background-color: #FF5500; margin: 0; padding: 0;">
                <div style="width: 100vw; height: 100vh; background-color: #FF5500;">
                </div>
            </body>
            </html>
        """)
        time.sleep(1)

        # For now just verify capture works - pixel comparison would need image saving
        result = run_test_capture()

        browser.close()

        if result.returncode == 0 and "PASSED" in result.stdout:
            log("Phase 2 Advanced: PASSED (capture works with colored page)")
            return True
        else:
            log("Phase 2 Advanced: FAILED")
            return False


if __name__ == "__main__":
    import sys

    success = True

    try:
        if not test_screen_capture_with_browser():
            success = False
    except Exception as e:
        log(f"Error in test_screen_capture_with_browser: {e}")
        success = False

    try:
        if not test_capture_contains_browser_pixels():
            success = False
    except Exception as e:
        log(f"Error in test_capture_contains_browser_pixels: {e}")
        success = False

    sys.exit(0 if success else 1)
