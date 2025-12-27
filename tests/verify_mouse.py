#!/usr/bin/env python3
"""
Mouse verification script for Zikuli Phase 5.

This script verifies mouse control functionality using X11/Xlib.
It reads mouse position and can detect button events.

Usage:
    python3 verify_mouse.py --check-position
    python3 verify_mouse.py --verify-move <x> <y>
    python3 verify_mouse.py --watch-buttons
"""

import argparse
import subprocess
import sys
import time

def get_mouse_position():
    """Get current mouse position using xwininfo and xinput."""
    try:
        # Use xdotool if available
        result = subprocess.run(
            ['xdotool', 'getmouselocation', '--shell'],
            capture_output=True, text=True, timeout=5
        )
        if result.returncode == 0:
            pos = {}
            for line in result.stdout.strip().split('\n'):
                if '=' in line:
                    key, val = line.split('=')
                    pos[key] = int(val)
            return pos.get('X', -1), pos.get('Y', -1)
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass

    # Fallback: try using python3-xlib if available
    try:
        from Xlib import display
        d = display.Display()
        root = d.screen().root
        pointer = root.query_pointer()
        return pointer.root_x, pointer.root_y
    except ImportError:
        pass

    # Fallback: use xinput list-props
    try:
        result = subprocess.run(
            ['xinput', 'query-state', 'pointer:'],
            capture_output=True, text=True, timeout=5
        )
        # Parse position from output
        # Format varies, this is a best effort
        for line in result.stdout.split('\n'):
            if 'position' in line.lower():
                # Try to extract x,y
                parts = line.split()
                for i, p in enumerate(parts):
                    if p == 'x=' or p.startswith('x='):
                        pass  # Parse logic
        return -1, -1
    except:
        return -1, -1

def verify_move(expected_x, expected_y, tolerance=2):
    """Verify mouse moved to expected position within tolerance."""
    actual_x, actual_y = get_mouse_position()

    if actual_x == -1 or actual_y == -1:
        print(f"ERROR: Could not read mouse position")
        return False

    x_ok = abs(actual_x - expected_x) <= tolerance
    y_ok = abs(actual_y - expected_y) <= tolerance

    if x_ok and y_ok:
        print(f"PASS: Mouse at ({actual_x}, {actual_y}), expected ({expected_x}, {expected_y})")
        return True
    else:
        print(f"FAIL: Mouse at ({actual_x}, {actual_y}), expected ({expected_x}, {expected_y})")
        return False

def check_position():
    """Print current mouse position."""
    x, y = get_mouse_position()
    if x == -1 and y == -1:
        print("ERROR: Could not determine mouse position")
        print("Install xdotool or python3-xlib for mouse position tracking")
        return False
    print(f"Current mouse position: ({x}, {y})")
    return True

def watch_buttons(duration=10):
    """Watch for button events for specified duration."""
    print(f"Watching for mouse button events for {duration} seconds...")
    print("Press Ctrl+C to stop")

    try:
        # Use xinput test to watch for events
        proc = subprocess.Popen(
            ['xinput', 'test-xi2', '--root'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True
        )

        start = time.time()
        while time.time() - start < duration:
            line = proc.stdout.readline()
            if line:
                if 'ButtonPress' in line or 'ButtonRelease' in line:
                    print(line.strip())

        proc.terminate()
        return True

    except FileNotFoundError:
        print("ERROR: xinput not available for button watching")
        return False
    except KeyboardInterrupt:
        print("\nStopped watching")
        return True

def main():
    parser = argparse.ArgumentParser(description='Mouse verification for Zikuli')
    parser.add_argument('--check-position', action='store_true',
                       help='Print current mouse position')
    parser.add_argument('--verify-move', nargs=2, type=int, metavar=('X', 'Y'),
                       help='Verify mouse is at specified position')
    parser.add_argument('--watch-buttons', action='store_true',
                       help='Watch for button press/release events')
    parser.add_argument('--duration', type=int, default=10,
                       help='Duration to watch buttons (default: 10s)')

    args = parser.parse_args()

    if args.check_position:
        sys.exit(0 if check_position() else 1)
    elif args.verify_move:
        sys.exit(0 if verify_move(args.verify_move[0], args.verify_move[1]) else 1)
    elif args.watch_buttons:
        sys.exit(0 if watch_buttons(args.duration) else 1)
    else:
        parser.print_help()
        sys.exit(1)

if __name__ == '__main__':
    main()
