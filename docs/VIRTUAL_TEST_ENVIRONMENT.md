# Zikuli Virtual Test Environment

A deterministic, reproducible testing environment for Zikuli using Xvfb (X Virtual Framebuffer).

## Quick Start

### 1. Install Dependencies

```bash
sudo apt-get install -y xvfb xdotool xserver-xephyr
```

### 2. Run Tests

**Headless (CI-friendly):**
```bash
./tests/scripts/run_virtual_tests.sh
```

**Visual Debug Mode (see what's happening):**
```bash
./tests/scripts/debug_visual.sh
```

**Run specific test:**
```bash
./tests/scripts/run_virtual_tests.sh test-virtual
```

### 3. Manual Testing

```bash
# Start Xvfb
Xvfb :99 -screen 0 1920x1080x24 -ac &

# Set display
export DISPLAY=:99

# Run Zikuli commands or tests
~/.zig/zig build test-virtual
./zig-out/bin/zikuli capture -o /tmp/test.png
```

---

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                    Test Harness                        │
│           (harness.zig - orchestrates flow)            │
└────────────┬──────────────────────┬───────────────────┘
             │                      │
     ┌───────▼───────┐      ┌───────▼───────┐
     │    Xvfb       │      │ Content Server │
     │ (Real X11)    │      │ (Places test   │
     │  Display :99  │      │  content at    │
     │  1920x1080x24 │      │  exact pixels) │
     └───────┬───────┘      └───────┬───────┘
             │                      │
             └──────────┬───────────┘
                        │
             ┌──────────▼──────────┐
             │ Zikuli (unchanged)  │
             │ - Screen Capture    │
             │ - Template Matching │
             │ - Mouse/Keyboard    │
             └─────────────────────┘
                        │
             ┌──────────▼──────────┐
             │ Verification Layer  │
             │ - Check mouse pos   │
             │ - Verify pixel color│
             │ - Compare regions   │
             └─────────────────────┘
```

---

## Components

### 1. Virtual Display (Xvfb)

Real X11 server with in-memory framebuffer:

| Option | Value | Purpose |
|--------|-------|---------|
| Display | `:99` | Avoids conflicts with real display |
| Screen | `1920x1080x24` | Standard resolution, 24-bit color |
| `-ac` | enabled | Disables access control |
| `-nolisten tcp` | enabled | Security: no network access |

### 2. Content Server (`content_server.zig`)

Places test content at exact pixel coordinates using **override-redirect windows** (bypasses window manager).

```zig
var server = try ContentServer.init(allocator);
defer server.deinit();

// Create window at exact position
var win = try server.createWindow(100, 200, 50, 50);
win.fillColor(255, 0, 0);  // Red
win.map();
server.sync();
```

Features:
- Exact (x, y) coordinate placement
- Solid color fills
- No window manager decoration
- Immediate visibility

### 3. Verification Layer (`verification.zig`)

Validates that Zikuli operations worked correctly:

```zig
var verifier = try Verifier.init(allocator);
defer verifier.deinit();

// Verify mouse position (with 5px tolerance)
try verifier.expectMouseAt(500, 300, 5);

// Verify pixel color at location
try verifier.expectColorAt(125, 125, 255, 0, 0, 10);

// Get current mouse position
const pos = try verifier.getMousePosition();
```

### 4. Test Harness (`harness.zig`)

Orchestrates the complete test flow:

```zig
var harness = try TestHarness.init(allocator);
defer harness.deinit();

// Place test content
_ = try harness.placeColorSquare(400, 300, 50, .{ .r = 255, .g = 0, .b = 0 });

// Setup full test scene (3 colored squares)
try harness.setupTestScene();

// Verify all placed content is visible
try harness.verifyAllVisible();
```

### 5. Test Fixtures (`tests/fixtures/patterns/`)

Pre-generated test images:

| Fixture | Size | Description |
|---------|------|-------------|
| `red_square_30x30.png` | 30x30 | Basic template matching |
| `blue_square_50x50.png` | 50x50 | Larger pattern |
| `button_ok.png` | 60x25 | Button with text |
| `crosshair_red_30.png` | 30x30 | Precision targeting |
| `checker_60x60_10.png` | 60x60 | Pattern matching edge case |
| `unique_40x40.png` | 40x40 | Unique unmatchable pattern |

Generate fixtures:
```bash
python3 tests/scripts/generate_fixtures.py
```

---

## Directory Structure

```
tests/
├── virtual/
│   ├── harness.zig           # Test orchestration
│   ├── content_server.zig    # Places test content on X11
│   ├── verification.zig      # Result verification utilities
│   └── test_virtual.zig      # Comprehensive test suite
├── fixtures/
│   └── patterns/             # Pre-generated test images
│       ├── red_square_*.png
│       ├── blue_square_*.png
│       ├── button_*.png
│       └── ...
└── scripts/
    ├── run_virtual_tests.sh  # Headless test runner
    ├── debug_visual.sh       # Visual debug mode (Xephyr)
    └── generate_fixtures.py  # Fixture generation script
```

---

## Build Targets

```bash
# Run virtual environment tests
~/.zig/zig build test-virtual

# Run virtual harness unit tests
~/.zig/zig build test-virtual-unit
```

---

## Test Categories

### Level 1: Screen Capture
- Full screen capture
- Region capture
- Pixel color verification

### Level 2: Mouse Control
- Move to position
- Click at position
- Position verification

### Level 3: Template Matching
- Exact color matching
- No-match returns null
- Similarity thresholds

### Level 4: Integration
- Find and click workflows
- Multi-target scenes
- Edge cases (corners, small patterns)

---

## Writing Tests

Use `harness.runVirtualTest()` for automatic setup/cleanup:

```zig
test "my virtual test" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place content
            _ = try h.placeColorSquare(100, 100, 50, .{ .r = 255, .g = 0, .b = 0 });
            std.time.sleep(100 * std.time.ns_per_ms);

            // Run Zikuli operations
            var capture = try zikuli.ScreenCapture.init(h.allocator);
            defer capture.deinit();
            var image = try capture.capture();
            defer image.deinit();

            // Verify
            const pixel = image.getPixel(125, 125) catch return;
            try std.testing.expect(pixel.r > 200);  // Red pixel
        }
    }.run);
}
```

---

## Debug Mode (Xephyr)

See tests running visually:

```bash
./tests/scripts/debug_visual.sh
```

This opens a window where you can watch Zikuli operations in real-time.

---

## CI Integration

For GitHub Actions or similar:

```yaml
- name: Install X11 dependencies
  run: sudo apt-get install -y xvfb xdotool

- name: Run Zikuli tests
  run: xvfb-run -a -s "-screen 0 1920x1080x24" ~/.zig/zig build test-virtual
```

---

## Resource Requirements

| Resource | Usage |
|----------|-------|
| RAM | ~50MB (Xvfb + framebuffer at 1080p) |
| Disk | ~10MB (test fixtures) |
| CPU | Minimal |
| Display | None required |

---

## Troubleshooting

### "No X11 display available"
```bash
export DISPLAY=:99
Xvfb :99 -screen 0 1920x1080x24 -ac &
```

### "Xvfb failed to start"
Check if display :99 is in use:
```bash
pkill -f "Xvfb :99"
```

### Tests pass locally but fail in CI
Ensure Xvfb is started before tests:
```bash
xvfb-run -a -s "-screen 0 1920x1080x24" your_test_command
```

### Template matching not finding patterns
- Increase similarity threshold tolerance
- Add `std.time.sleep(100 * std.time.ns_per_ms)` after placing content
- Verify content is placed with `harness.printPlacedContent()`

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Display Server | Xvfb | ~10MB RAM, headless, CI-standard, real X11 protocol |
| Window Manager | None | Determinism, exact pixel control, no interference |
| Content Placement | Override-redirect windows | No WM decoration, exact position |
| Debug Mode | Xephyr | Visual window for development debugging |
| Resolution | Runtime configurable | Any resolution via Xvfb args |
