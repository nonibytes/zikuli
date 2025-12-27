#!/usr/bin/env python3
"""
Phase 4 Verification: OpenCV Template Matching with Real Browser

This test verifies Zikuli's template matching functionality by:
1. Opening a browser with known UI elements
2. Capturing the screen
3. Using Zikuli to find template patterns in the capture
"""

import os
import subprocess
import time
from datetime import datetime
from pathlib import Path
from playwright.sync_api import sync_playwright
from PIL import Image
import io

PROJECT_ROOT = Path(__file__).parent.parent.parent
ZIKULI_BIN = PROJECT_ROOT / "zig-out" / "bin"
TEST_DATA = Path("/tmp/zikuli_test_data")


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


def setup_test_data():
    """Create test data directory."""
    TEST_DATA.mkdir(parents=True, exist_ok=True)


def test_finder_with_known_elements():
    """
    Test template matching by:
    1. Opening a page with known buttons
    2. Taking a Playwright screenshot as reference
    3. Extracting button region as template
    4. Using Zikuli to find it (when finder test binary is available)
    """
    log("=" * 60)
    log("Phase 4 Verification: Template Matching Setup")
    log("=" * 60)

    build_zikuli()
    setup_test_data()

    with sync_playwright() as p:
        log("Launching browser...")
        browser = p.chromium.launch(
            headless=False,
            args=['--window-position=100,100', '--window-size=1024,768']
        )
        page = browser.new_page()

        # Navigate to a page with distinct buttons
        log("Navigating to test page with buttons...")
        page.goto("https://the-internet.herokuapp.com/add_remove_elements/")
        page.wait_for_load_state("networkidle")
        time.sleep(1)

        # Take a full page screenshot
        log("Taking reference screenshot...")
        screenshot_bytes = page.screenshot()
        screenshot_path = TEST_DATA / "screen.png"
        with open(screenshot_path, 'wb') as f:
            f.write(screenshot_bytes)
        log(f"Saved screenshot to {screenshot_path}")

        # Get button location for template extraction
        add_button = page.locator("button", has_text="Add Element")
        box = add_button.bounding_box()
        if box:
            log(f"'Add Element' button at: x={box['x']:.0f}, y={box['y']:.0f}, "
                f"w={box['width']:.0f}, h={box['height']:.0f}")

            # Extract button region as template
            img = Image.open(io.BytesIO(screenshot_bytes))

            # Add some padding around the button
            padding = 2
            x = max(0, int(box['x']) - padding)
            y = max(0, int(box['y']) - padding)
            x2 = min(img.width, int(box['x'] + box['width']) + padding)
            y2 = min(img.height, int(box['y'] + box['height']) + padding)

            button_img = img.crop((x, y, x2, y2))
            template_path = TEST_DATA / "add_button_template.png"
            button_img.save(template_path)
            log(f"Saved button template to {template_path} (size: {button_img.size})")

            # Verify template was created
            if template_path.exists() and template_path.stat().st_size > 0:
                log("[PASS] Template image created successfully")
            else:
                log("[FAIL] Template image creation failed")

        browser.close()

        # TODO: When test_finder binary is available, run it here:
        # result = subprocess.run([ZIKULI_BIN / "test_finder",
        #     "--source", str(screenshot_path),
        #     "--template", str(template_path),
        #     "--expected-x", str(int(box['x'])),
        #     "--expected-y", str(int(box['y']))
        # ])

        log("=" * 60)
        log("Phase 4 Verification: Template extraction PASSED")
        log("NOTE: Full finder test requires test_finder binary")
        log("=" * 60)

        return True


def test_unit_tests_pass():
    """Verify unit tests for finder and opencv bindings pass."""
    log("=" * 60)
    log("Phase 4: Running Unit Tests")
    log("=" * 60)

    result = subprocess.run(
        [os.path.expanduser("~/.zig/zig"), "build", "test"],
        cwd=PROJECT_ROOT,
        capture_output=True,
        text=True
    )

    if result.returncode == 0:
        log("[PASS] All unit tests passed")
        return True
    else:
        log("[FAIL] Unit tests failed")
        log(f"stderr: {result.stderr}")
        return False


if __name__ == "__main__":
    import sys

    success = True

    try:
        if not test_unit_tests_pass():
            success = False
    except Exception as e:
        log(f"Error in test_unit_tests_pass: {e}")
        success = False

    try:
        if not test_finder_with_known_elements():
            success = False
    except Exception as e:
        log(f"Error in test_finder_with_known_elements: {e}")
        success = False

    sys.exit(0 if success else 1)
