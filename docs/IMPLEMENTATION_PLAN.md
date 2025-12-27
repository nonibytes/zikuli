# Zikuli: Sikuli Re-implementation in Idiomatic Zig

## Executive Summary

Re-implement SikuliX as **Zikuli** - a native Zig library for visual GUI automation using image recognition. Faithful to Sikuli's capabilities but following Zig philosophy: no hidden allocations, explicit error handling, comptime where possible, and memory safety without garbage collection.

---

## Development Methodology

### Source-First Analysis Protocol

**BEFORE implementing ANY feature, analyze the SikuliX source code:**

1. **Read the Java source** in `/tmp/temp-github-repos/SikuliX1/`
2. **Read the C++ native code** in `/tmp/temp-github-repos/sikuli-original/sikuli-script/src/main/native/`
3. **Document key algorithms, constants, and edge cases**
4. **Identify all behavior that must be preserved**
5. **Only THEN begin Zig implementation**

### Session Context Recovery

Claude Code sessions may lose context due to conversation clearing/compaction. To recover previous work:

```bash
# Get session file path
SESSION_FILE="$CLAUDE_SESSIONS_DATA_PATH/$(cat $CLAUDE_SESSION_FILE).jsonl"

# View last 5 user messages
grep '"type":"user"' "$SESSION_FILE" | grep -v '"tool_result"' | tail -5 | \
  jq -r 'if .message.content | type == "string" then .message.content else .message.content[0].text // empty end' 2>/dev/null

# View last 5 assistant responses
grep '"type":"assistant"' "$SESSION_FILE" | tail -5 | \
  jq -r '[.message.content[] | select(.type=="text") | .text] | join("\n")' 2>/dev/null | head -200

# Check for summary (indicates compaction happened)
grep '"type":"summary"' "$SESSION_FILE" | jq -r '.summary' 2>/dev/null
```

**Use this proactively when:**
- Resuming work after a break
- Context seems incomplete
- Need to verify previous decisions
- Recovering file paths, variable names, or code snippets

### Verification-First Development

For each feature:
```
1. Analyze SikuliX source code FIRST
2. Write verification tests (must initially FAIL)
3. Implement the feature
4. Run tests (must PASS)
5. Run full regression (NO regressions allowed)
6. Manual verification with actual execution
7. Playwright Python real-world verification (see below)
8. SPAWN PARANOID REVIEWER AGENT (see below) - MANDATORY
9. Fix all issues raised by reviewer
10. Commit with evidence
```

### Paranoid Reviewer Agent (MANDATORY after EVERY phase)

**After completing each phase, you MUST spawn a paranoid code reviewer agent.**

This is NON-NEGOTIABLE. The agent catches bugs, security issues, and correctness problems
that are easy to miss during implementation.

**When to Spawn:**
- Immediately after all tests pass for the phase
- Before committing any phase completion
- After any significant code changes

**How to Spawn:**
```
Use the Task tool with subagent_type='general-purpose' with a detailed review prompt
```

**Agent Prompt Template:**
```
You are a paranoid code reviewer for the Zikuli project (Sikuli re-implementation in Zig).

Review Phase X: [Phase Name]

Files to review:
- [list all files created/modified in this phase]

Check for:
1. CORRECTNESS: Does this match Sikuli's behavior? Reference SikuliX source at /tmp/temp-github-repos/SikuliX1/
2. MEMORY SAFETY: Any leaks, use-after-free, buffer overflows?
3. ERROR HANDLING: All error paths handled? Errors propagated correctly?
4. EDGE CASES: Zero sizes, negative coords, null pointers, empty arrays?
5. SECURITY: Any injection risks, unsafe operations?
6. PLATFORM: Will this work on different Linux distros? X11 vs Wayland concerns?
7. PERFORMANCE: Any obvious inefficiencies?
8. IDIOMS: Is this idiomatic Zig? Using std lib correctly?

For each issue found, provide:
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- Location: file:line
- Issue: Description
- Fix: Suggested fix

Read all files thoroughly. Be paranoid. Assume there are bugs until proven otherwise.
```

**Process:**
1. Spawn agent with files list
2. Wait for agent to complete review
3. Fix ALL issues marked CRITICAL or HIGH immediately
4. Fix MEDIUM issues before commit
5. Document LOW issues in code comments if not fixing
6. Re-run agent if significant changes made

### Real-World Web Automation Verification (REQUIRED for ALL phases)

**EVERY phase MUST include Playwright Python verification tests** that validate Zikuli functionality in real-world browser scenarios.

**Process:**
1. Create test script in `tests/playwright/test_phase_X.py`
2. Use Playwright to set up test scenarios (open browser, navigate to test sites)
3. Run Zikuli operations against the browser window
4. Use Playwright to verify results (compare screenshots, check element states)
5. Log all operations with timestamps

**Test Websites to Use:**
- `https://the-internet.herokuapp.com` - Various UI patterns (buttons, forms, dropdowns)
- `https://demo.playwright.dev/todomvc` - Interactive app with state
- `https://www.google.com` - Search functionality
- `https://example.com` - Simple static page

**Playwright Python Test Template:**
```python
#!/usr/bin/env python3
"""Phase X: Real-world verification test using Playwright + Zikuli"""

import subprocess
import time
from datetime import datetime
from playwright.sync_api import sync_playwright

def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S.%f')[:-3]}] {msg}")

def run_zikuli(args: list) -> subprocess.CompletedProcess:
    """Run Zikuli test binary and return result."""
    cmd = ["./zig-out/bin/test_binary"] + args
    log(f"Running: {' '.join(cmd)}")
    result = subprocess.run(cmd, capture_output=True, text=True)
    log(f"Exit code: {result.returncode}")
    if result.stdout:
        log(f"stdout: {result.stdout}")
    if result.stderr:
        log(f"stderr: {result.stderr}")
    return result

def test_phase_X():
    log("Starting Phase X verification")

    with sync_playwright() as p:
        # Launch browser
        browser = p.chromium.launch(headless=False)
        page = browser.new_page()

        # Navigate to test site
        page.goto("https://the-internet.herokuapp.com")
        log("Browser opened and navigated")

        # Wait for page to be ready
        page.wait_for_load_state("networkidle")
        time.sleep(1)  # Allow Zikuli time to capture stable screen

        # TODO: Run Zikuli operations here
        # result = run_zikuli(["--action", "capture", "--output", "/tmp/screen.png"])
        # assert result.returncode == 0, "Zikuli capture failed"

        # TODO: Verify with Playwright
        # screenshot = page.screenshot()
        # assert compare_images(screenshot, "/tmp/screen.png")

        browser.close()

    log("Phase X verification PASSED")

if __name__ == "__main__":
    test_phase_X()
```

**Requirements:**
```bash
# Install Playwright Python
pip install playwright
playwright install chromium
```

**Why This Matters:**
- Unit tests verify isolated functionality
- Playwright tests verify real-world integration
- Together they ensure Zikuli actually works for GUI automation

---

## SikuliX Architecture Analysis (Completed)

### Core Components Analyzed

| Component | SikuliX Class | Size | Purpose |
|-----------|---------------|------|---------|
| **Region** | `Region.java` | 144KB | Rectangular screen area, all find/action operations |
| **Finder** | `Finder.java` | 43KB | OpenCV `matchTemplate()` image matching |
| **Screen** | `Screen.java` | 20KB | Physical monitor, screen capture |
| **Image** | `Image.java` | 36KB | Image loading and management |
| **Pattern** | `Pattern.java` | 8KB | Search target with similarity/offset |
| **Match** | `Match.java` | 7KB | Find result, extends Region |
| **Mouse** | `Mouse.java` | 14KB | Mouse click, move, drag, wheel |
| **Key** | `Key.java` | 29KB | Keyboard input simulation |
| **OCR** | `OCR.java` | 25KB | Text recognition via Tesseract |
| **RobotDesktop** | `RobotDesktop.java` | 13KB | Low-level OS interaction |
| **ScreenDevice** | `ScreenDevice.java` | 7KB | Screen enumeration and capture |

### Key Dependencies for Zig

1. **Screen Capture**: X11/XCB (`xcb_get_image`, `XShmGetImage`)
2. **Image Matching**: OpenCV via [zigcv](https://github.com/ryoppippi/zigcv) or C FFI
3. **Mouse/Keyboard**: X11 XTest extension or libevdev
4. **OCR** (optional): Tesseract C API

---

## Detailed SikuliX Implementation Analysis

### Image Matching Algorithm (from Finder.java)

**SikuliX uses OpenCV `matchTemplate()` with these specifics:**

```java
// Method selection based on image type:
if (!plainColor) {
    // Regular images: TM_CCOEFF_NORMED (normalized cross-correlation coefficient)
    Imgproc.matchTemplate(where, what, result, Imgproc.TM_CCOEFF_NORMED);
} else {
    // Plain/solid color images: TM_SQDIFF_NORMED (sum of squared differences)
    Imgproc.matchTemplate(where, what, result, Imgproc.TM_SQDIFF_NORMED);
    // For SQDIFF, invert to get similarity: result = 1 - result
    Core.subtract(Mat.ones(result.size(), CvType.CV_32F), result, result);
}

// Find best match location
Core.MinMaxLocResult minMax = Core.minMaxLoc(result);
if (minMax.maxVal >= threshold) {
    // Match found at minMax.maxLoc
}
```

**Plain color detection:** `stdDev < 1.0E-5` indicates solid color image

**findAll() algorithm:**
1. Find peak in result matrix via `minMaxLoc()`
2. Accept if score > threshold
3. Zero out region around match: `margin = targetSize * 0.8`
4. Repeat until no more matches above threshold

**"Still-there" optimization:**
- Cache last found location in `Image.lastSeen`
- On next find, first search only in cached region with `threshold - 0.01`
- If found, return immediately (massive speedup)
- If not found, fall back to full search

### Mouse Control (from Mouse.java, RobotDesktop.java)

**Smooth movement uses quartic easing:**
```java
// AnimatorOutQuarticEase formula:
// t1 = t / totalTime  (normalized time 0→1)
// position = start + (end - start) * (-t^4 + 4t^3 - 6t^2 + 4t)
// This creates "ease-out" curve: fast start, slow finish
```

**Thread safety via Device class:**
```java
// Device.use(owner) - acquire exclusive lock, wait if busy
// Device.let(owner) - release lock, notify waiting threads
// External mouse movement detection built-in
```

**Button constants:**
```java
LEFT   = InputEvent.BUTTON1_MASK  // 1024
MIDDLE = InputEvent.BUTTON2_MASK  // 2048
RIGHT  = InputEvent.BUTTON3_MASK  // 4096
```

### Keyboard Control (from RobotDesktop.java, KeyboardLayout.java)

**Key state tracking:**
```java
private static String heldKeys = "";           // Character keys held
private static ArrayList<Integer> heldKeyCodes = new ArrayList<>();  // Keycodes held
```

**Modifier handling:**
```java
// Modifiers pressed before key, released after
SHIFT = InputEvent.SHIFT_MASK   // 64
CTRL  = InputEvent.CTRL_MASK    // 128
ALT   = InputEvent.ALT_MASK     // 512
META  = InputEvent.META_MASK    // 4
ALTGR = InputEvent.ALT_GRAPH_MASK // 8192
```

### Screen Capture (from ScreenDevice.java)

**Java implementation:**
```java
// Uses java.awt.Robot.createScreenCapture(Rectangle)
// Each monitor has its own Robot instance via GraphicsDevice
GraphicsDevice[] devices = GraphicsEnvironment.getLocalGraphicsEnvironment().getScreenDevices();
Robot robot = new Robot(devices[monitorIndex]);
BufferedImage screenshot = robot.createScreenCapture(bounds);
```

**Multi-monitor:** Primary screen contains point (0,0), others offset by their bounds

**For Zig equivalent:** Use XCB's `xcb_get_image()` or XShm for faster capture

---

## Native C++ Algorithm Analysis (sikuli-original)

### PyramidTemplateMatcher (pyramid-template-matcher.cpp)

**Coarse-to-Fine Matching Algorithm:**

```cpp
// Constructor creates recursive pyramid
PyramidTemplateMatcher(data, levels, factor) {
    if (levels > 0)
        lowerPyramid = createSmallMatcher(levels - 1);  // Recursive
}

// createSmallMatcher downsamples by factor
PyramidTemplateMatcher* createSmallMatcher(int level) {
    return new PyramidTemplateMatcher(
        data.createSmallData(factor),  // Downsample source AND target
        level,
        factor
    );
}

// Matching at each level
FindResult nextFromLowerPyramid() {
    // 1. Get match from lower (smaller) pyramid
    FindResult match = lowerPyramid->next();

    // 2. Scale up coordinates
    int x = match.x * factor;
    int y = match.y * factor;

    // 3. Define search region around scaled match (±factor pixels)
    Rect roi(
        max(x - factor, 0),
        max(y - factor, 0),
        min(x + target.cols + factor, source.cols),
        min(y + target.rows + factor, source.rows)
    );

    // 4. Re-match in small ROI at current resolution
    double score = findBest(data, &roi, result, detectedLoc);

    // 5. Adjust for ROI offset
    return FindResult(detectedLoc.x + roi.x, detectedLoc.y + roi.y, ...);
}
```

**findBest() - OpenCV matchTemplate selection:**

```cpp
double findBest(data, roi, out_result, out_location) {
    if (data.isSameColor()) {
        // Plain color: use SQDIFF on original (not gray)
        if (data.isBlack()) {
            // Black: invert both images first
            bitwise_not(source, inv_source);
            bitwise_not(target, inv_target);
            matchTemplate(inv_source, inv_target, result, CV_TM_SQDIFF_NORMED);
        } else {
            matchTemplate(source, target, result, CV_TM_SQDIFF_NORMED);
        }
        // Invert SQDIFF to get similarity: result = 1 - result
        result = Mat::ones(result.size(), CV_32F) - result;
    } else {
        // Regular images: cross-correlation coefficient
        matchTemplate(source, target, result, CV_TM_CCOEFF_NORMED);
    }

    minMaxLoc(result, NULL, &score, NULL, &location);
    return score;
}
```

**Plain color detection:**
```cpp
bool isSameColor() { return stddev[0]+stddev[1]+stddev[2]+stddev[3] <= 1e-5; }
bool isBlack() { return mean[0]+mean[1]+mean[2]+mean[3] <= 1e-5 && isSameColor(); }
```

**Match suppression for findAll:**
```cpp
void eraseResult(int x, int y, int xmargin, int ymargin) {
    // Zero out region around match to find next one
    result(Range(y-ymargin, y+ymargin), Range(x-xmargin, x+xmargin)) = 0.f;
}
// Margin = targetSize / 3
int xmargin = target.cols / 3;
int ymargin = target.rows / 3;
```

### TemplateFinder (finder.cpp)

**Multi-resolution matching strategy:**

```cpp
// Constants
#define DEFAULT_PYRAMID_MIN_TARGET_DIMENSION 12
#define PYRAMID_MIN_TARGET_DIMENSION_ALL 50
#define REMATCH_THRESHOLD 0.9

void find(Mat target, double min_similarity) {
    // Calculate pyramid factor based on target size
    float ratio = min(target.rows / 12.0, target.cols / 12.0);
    if (ratio < 1.0) ratio = 1.0;

    // Try multiple resize ratios
    const float resize_ratios[] = {1.0, 0.75, 0.5, 0.25};
    for (float r : resize_ratios) {
        float new_ratio = ratio * r;
        if (new_ratio >= 1.0) {
            create_matcher(data, 1, new_ratio);
            add_matches_to_buffer(5);
            if (top_score >= max(min_similarity, 0.9))
                return;  // Good enough match found
        }
    }

    // Fall back to grayscale at original resolution
    if (data.useGray()) {
        create_matcher(data, 0, 1);
        add_matches_to_buffer(5);
        if (top_score >= 0.9) return;
    }

    // Final: color at original resolution
    create_matcher(data, 0, 1);
    add_matches_to_buffer(5);
}
```

### Key Constants for Zig Implementation

| Constant | Value | Purpose |
|----------|-------|---------|
| `MIN_TARGET_DIMENSION` | 12 | Stop pyramid when target < 12px |
| `MIN_TARGET_DIMENSION_ALL` | 50 | For findAll, stop at 50px |
| `REMATCH_THRESHOLD` | 0.9 | Accept pyramid match if score ≥ 0.9 |
| `ERASE_MARGIN` | targetSize / 3 | Suppress nearby matches |
| `MIN_SIMILARITY` | 0.7 | Default threshold |
| `PLAIN_COLOR_STDDEV` | 1e-5 | Threshold for solid color detection |
| `GPU_MIN_PIXELS` | 90000 | Use GPU if source > 90K pixels |

---

## Implementation Plan

### Phase 0: Project Setup & Toolchain Verification
**Estimated Files**: 5 | **Validation**: Build system works

```
/home/okecho/nonibytes/zikuli/
├── build.zig                 # Build configuration
├── build.zig.zon             # Dependencies
├── src/
│   ├── main.zig              # Library entry point
│   └── root.zig              # Root module exports
├── tests/
│   └── main_test.zig         # Test runner
├── examples/
│   └── hello_screen.zig      # Basic usage example
└── CLAUDE.md                 # Development notes
```

**Validation Checkpoints**:
- [ ] `zig build` succeeds
- [ ] `zig build test` runs (even if empty)
- [ ] Can create a simple executable

**Commit**: `feat: initial project structure with build system`

---

### Phase 1: Core Types & Geometry
**Estimated Files**: 4 | **Validation**: Unit tests pass

**Files to Create**:
- `src/geometry.zig` - Point, Rectangle, Location types
- `src/region.zig` - Region type (without screen operations yet)
- `src/match.zig` - Match type (result of find)
- `src/pattern.zig` - Pattern type (search target)

**Zig Philosophy Applied**:
```zig
// Explicit, stack-allocated geometry
pub const Point = struct {
    x: i32,
    y: i32,

    pub fn offset(self: Point, dx: i32, dy: i32) Point {
        return .{ .x = self.x + dx, .y = self.y + dy };
    }
};

pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub fn center(self: Rectangle) Point {
        return .{
            .x = self.x + @as(i32, @intCast(self.width / 2)),
            .y = self.y + @as(i32, @intCast(self.height / 2)),
        };
    }

    pub fn contains(self: Rectangle, p: Point) bool {
        return p.x >= self.x and p.x < self.x + @as(i32, @intCast(self.width))
           and p.y >= self.y and p.y < self.y + @as(i32, @intCast(self.height));
    }
};
```

**Validation Checkpoints**:
- [ ] Point arithmetic works correctly
- [ ] Rectangle intersection/union works
- [ ] Center calculation is accurate
- [ ] All edge cases tested (negative coords, zero size)

**Paranoid Review Focus**: Overflow handling, coordinate edge cases

**Commit**: `feat: implement core geometry types with tests`

---

### Phase 2: X11/XCB Screen Capture
**Estimated Files**: 3 | **Validation**: Actually captures screen

**Files to Create**:
- `src/platform/linux.zig` - Linux-specific implementations
- `src/platform/x11.zig` - X11 connection and screen capture
- `src/screen.zig` - Platform-agnostic Screen abstraction

**Core Implementation**:
```zig
// src/platform/x11.zig
const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_image.h");
    @cInclude("xcb/shm.h");
});

pub const X11Screen = struct {
    connection: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,

    pub fn capture(self: *X11Screen, rect: Rectangle) !Image {
        // Use XCB to get image data
        const cookie = c.xcb_get_image(
            self.connection,
            c.XCB_IMAGE_FORMAT_Z_PIXMAP,
            self.screen.root,
            @intCast(rect.x), @intCast(rect.y),
            @intCast(rect.width), @intCast(rect.height),
            ~@as(u32, 0)
        );
        // ... handle reply and convert to Image
    }
};
```

**Validation Checkpoints**:
- [ ] Can connect to X11 display
- [ ] Can enumerate screens/monitors
- [ ] Screenshot captures correct region
- [ ] Screenshot pixel data is correct (validate with known image)
- [ ] Multi-monitor setup works
- [ ] Screenshot saved to PNG matches visual expectation

**REAL VALIDATION TEST**:
```bash
# Capture screenshot and verify visually
./zig-out/bin/test_capture --rect 0,0,100,100 --output /tmp/capture.png
# Compare with reference or visual inspection
```

**Paranoid Review Focus**: Memory leaks in X11 resources, error handling for disconnected displays

**Commit**: `feat: implement X11 screen capture with XCB`

---

### Phase 3: Image Handling
**Estimated Files**: 3 | **Validation**: Load/save images correctly

**Files to Create**:
- `src/image.zig` - Image type and operations
- `src/image/png.zig` - PNG encode/decode (use stb_image or lodepng)
- `src/image/convert.zig` - Format conversions (BGRA <-> RGBA, etc.)

**Image Type**:
```zig
pub const Image = struct {
    data: []u8,           // Pixel data (owned)
    width: u32,
    height: u32,
    format: PixelFormat,
    allocator: std.mem.Allocator,

    pub const PixelFormat = enum {
        rgba,
        bgra,
        rgb,
        grayscale,
    };

    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }

    pub fn fromFile(allocator: std.mem.Allocator, path: []const u8) !Image {
        // Load PNG using stb_image or lodepng
    }

    pub fn savePng(self: *const Image, path: []const u8) !void {
        // Save to PNG
    }
};
```

**Validation Checkpoints**:
- [ ] Load PNG file correctly
- [ ] Save PNG file correctly
- [ ] Round-trip (load → save → load) produces identical data
- [ ] Handle various PNG formats (8-bit, 16-bit, alpha, no alpha)
- [ ] Memory is properly freed

**Paranoid Review Focus**: Memory leaks, buffer overflows in image loading

**Commit**: `feat: implement image loading and saving`

---

### Phase 4: OpenCV Integration & Template Matching
**Estimated Files**: 3 | **Validation**: Image matching works

**Files to Create**:
- `src/opencv/bindings.zig` - OpenCV C API bindings
- `src/opencv/matcher.zig` - Template matching wrapper
- `src/finder.zig` - High-level Finder (like Sikuli's)

**Core Matching**:
```zig
pub const Finder = struct {
    source_image: Image,
    min_similarity: f64 = 0.7,

    pub fn find(self: *Finder, template: Image) ?Match {
        // Call OpenCV matchTemplate via C FFI
        const result = opencv.matchTemplate(
            self.source_image.toMat(),
            template.toMat(),
            .TM_CCOEFF_NORMED
        );

        const min_max = opencv.minMaxLoc(result);
        if (min_max.max_val >= self.min_similarity) {
            return Match{
                .x = min_max.max_loc.x,
                .y = min_max.max_loc.y,
                .width = template.width,
                .height = template.height,
                .score = min_max.max_val,
            };
        }
        return null;
    }

    pub fn findAll(self: *Finder, template: Image) ![]Match {
        // Find all matches above threshold
    }
};
```

**Validation Checkpoints**:
- [ ] OpenCV library links correctly
- [ ] matchTemplate produces correct results on known images
- [ ] Similarity threshold works (test with exact match = 1.0)
- [ ] findAll returns multiple matches correctly
- [ ] No matches returns empty/null appropriately
- [ ] Performance is reasonable (< 100ms for typical screen/template)

**REAL VALIDATION TEST**:
```bash
# Create test image with known pattern
# Search for pattern and verify coordinates match expected
./zig-out/bin/test_finder --source screen.png --template button.png --expected-x 100 --expected-y 200
```

**Paranoid Review Focus**: OpenCV Mat memory management, score calculation accuracy

**Commit**: `feat: implement OpenCV template matching`

---

### Phase 5: Mouse Control
**Estimated Files**: 2 | **Validation**: Mouse actually moves and clicks

**Files to Create**:
- `src/input/mouse.zig` - Mouse control
- `src/platform/x11_input.zig` - X11 XTest extension bindings

**Mouse API**:
```zig
pub const Mouse = struct {
    pub fn move(x: i32, y: i32) !void {
        // Use XTest to move mouse
    }

    pub fn smoothMove(from: Point, to: Point, duration_ms: u32) !void {
        // Animated movement using quartic easing
    }

    pub fn click(button: Button) !void {
        try down(button);
        try up(button);
    }

    pub fn down(button: Button) !void {
        // XTest button press
    }

    pub fn up(button: Button) !void {
        // XTest button release
    }

    pub fn wheel(direction: WheelDirection, steps: u32) !void {
        // Mouse wheel
    }

    pub fn at() !Point {
        // Query current mouse position
    }

    pub const Button = enum { left, right, middle };
    pub const WheelDirection = enum { up, down };
};
```

**Validation Checkpoints**:
- [ ] Mouse moves to correct position
- [ ] Mouse position query returns accurate coordinates
- [ ] Left click works
- [ ] Right click works
- [ ] Double click works
- [ ] Drag works (down, move, up sequence)
- [ ] Mouse wheel scrolls content
- [ ] Smooth move animation is visually correct

**REAL VALIDATION TEST**:
```bash
# Move mouse to corner and verify position
./zig-out/bin/test_mouse --action move --x 0 --y 0
# Verify mouse is at (0,0) - may need human verification or screenshot comparison

# Click test: open a text editor, position mouse, click
# Verify cursor appears at clicked location
```

**Paranoid Review Focus**: XTest error handling, coordinate accuracy

**Commit**: `feat: implement mouse control via XTest`

---

### Phase 6: Keyboard Control
**Estimated Files**: 2 | **Validation**: Keyboard actually types

**Files to Create**:
- `src/input/keyboard.zig` - Keyboard control
- `src/input/keycodes.zig` - Key code mappings

**Keyboard API**:
```zig
pub const Keyboard = struct {
    pub fn type_text(text: []const u8) !void {
        for (text) |char| {
            try typeChar(char);
        }
    }

    pub fn typeChar(char: u8) !void {
        const keycode = charToKeycode(char);
        const needs_shift = charNeedsShift(char);

        if (needs_shift) try keyDown(.shift);
        try keyDown(keycode);
        try keyUp(keycode);
        if (needs_shift) try keyUp(.shift);
    }

    pub fn keyDown(key: Key) !void { ... }
    pub fn keyUp(key: Key) !void { ... }

    pub fn hotkey(modifiers: []const Modifier, key: Key) !void {
        for (modifiers) |mod| try keyDown(mod.toKey());
        try keyDown(key);
        try keyUp(key);
        for (modifiers) |mod| try keyUp(mod.toKey());
    }
};
```

**Validation Checkpoints**:
- [ ] Single key press works
- [ ] Key modifiers (Shift, Ctrl, Alt) work
- [ ] Full text typing works correctly
- [ ] Special keys (Enter, Tab, Escape, F1-F12) work
- [ ] Hotkey combinations work (Ctrl+C, Alt+Tab)
- [ ] Non-ASCII characters handled (or explicit error)

**REAL VALIDATION TEST**:
```bash
# Open text editor, type text, verify it appears
./zig-out/bin/test_keyboard --type "Hello, World!"
# Verify "Hello, World!" appears in focused text field

# Test hotkey
./zig-out/bin/test_keyboard --hotkey "ctrl+a"
# Verify select-all happened
```

**Paranoid Review Focus**: Keycode correctness, modifier state cleanup

**Commit**: `feat: implement keyboard control via XTest`

---

### Phase 7: Region Operations
**Estimated Files**: 1 | **Validation**: Integration of all components

**Update**: `src/region.zig` - Full Region implementation

**Region API** (like Sikuli):
```zig
pub const Region = struct {
    rect: Rectangle,
    screen: *Screen,
    auto_wait_timeout: f64 = 3.0,

    // Find operations
    pub fn find(self: *Region, target: anytype) !Match {
        const image = try self.screen.capture(self.rect);
        defer image.deinit();

        var finder = Finder{ .source_image = image };
        return finder.find(patternFromTarget(target)) orelse error.FindFailed;
    }

    pub fn wait(self: *Region, target: anytype, timeout: ?f64) !Match {
        const deadline = timeout orelse self.auto_wait_timeout;
        const start = std.time.milliTimestamp();

        while (true) {
            if (self.find(target)) |match| return match;
            if (std.time.milliTimestamp() - start > deadline * 1000) {
                return error.FindFailed;
            }
            std.time.sleep(100 * std.time.ns_per_ms);
        }
    }

    pub fn exists(self: *Region, target: anytype) bool {
        return self.find(target) != null;
    }

    // Action operations
    pub fn click(self: *Region, target: anytype) !void {
        const match = try self.find(target);
        try Mouse.click(match.center());
    }

    pub fn doubleClick(self: *Region, target: anytype) !void { ... }
    pub fn rightClick(self: *Region, target: anytype) !void { ... }
    pub fn type_text(self: *Region, text: []const u8) !void { ... }

    // Region manipulation
    pub fn offset(self: Region, x: i32, y: i32) Region { ... }
    pub fn grow(self: Region, amount: i32) Region { ... }
    pub fn nearby(self: Region, range: u32) Region { ... }
    pub fn above(self: Region, height: ?u32) Region { ... }
    pub fn below(self: Region, height: ?u32) Region { ... }
    pub fn left(self: Region, width: ?u32) Region { ... }
    pub fn right(self: Region, width: ?u32) Region { ... }
};
```

**Validation Checkpoints**:
- [ ] find() returns correct Match for visible target
- [ ] wait() times out appropriately
- [ ] click() moves mouse and clicks at match center
- [ ] type_text() types text after clicking
- [ ] Region manipulation (above/below/left/right) calculates correctly
- [ ] exists() returns true/false correctly

**REAL VALIDATION TEST**:
```bash
# Full integration: find button, click it, type in resulting text field
./zig-out/bin/test_region --find button.png --click --type "test input"
```

**Paranoid Review Focus**: Memory management across operations, timeout accuracy

**Commit**: `feat: implement full Region operations`

---

### Phase 8: OCR Integration (Optional)
**Estimated Files**: 2 | **Validation**: Text extraction works

**Files to Create**:
- `src/ocr/tesseract.zig` - Tesseract C API bindings
- `src/ocr.zig` - High-level OCR wrapper

**Validation Checkpoints**:
- [ ] Tesseract library links correctly
- [ ] Text extraction from known image is accurate
- [ ] Word/line level detection works
- [ ] findText() locates text on screen

**Commit**: `feat: implement OCR with Tesseract`

---

### Phase 9: High-Level API & Examples
**Estimated Files**: 4 | **Validation**: Usable library

**Files to Create**:
- `src/zikuli.zig` - Public API (re-exports)
- `examples/basic_automation.zig` - Basic usage
- `examples/find_and_click.zig` - Find pattern and click
- `examples/type_text.zig` - Keyboard automation

**Public API**:
```zig
// Example usage
const zikuli = @import("zikuli");

pub fn main() !void {
    var screen = try zikuli.Screen.primary();
    defer screen.deinit();

    // Find and click a button
    const match = try screen.region().find("submit_button.png");
    try match.click();

    // Wait for something to appear
    const dialog = try screen.region().wait("dialog.png", 5.0);

    // Type text
    try zikuli.Keyboard.type_text("Hello, World!");
}
```

**Validation Checkpoints**:
- [ ] Examples compile and run
- [ ] API is ergonomic and Zig-idiomatic
- [ ] Error messages are helpful
- [ ] Documentation comments are accurate

**Commit**: `feat: add public API and examples`

---

### Phase 10: Real-World Automation Examples (FINAL VALIDATION)
**Estimated Files**: 5+ | **Validation**: Zikuli solves actual real-world tasks

This is the ultimate test of Zikuli - can it automate real applications?

**Real-World Tasks to Automate:**

1. **Web Browser Automation** (`examples/real_world/browser_automation.zig`)
   - Open Firefox/Chrome
   - Navigate to a website
   - Find and click a button
   - Fill in a form
   - Submit and verify result

2. **File Manager Automation** (`examples/real_world/file_manager.zig`)
   - Open file manager (Nautilus/Dolphin)
   - Navigate to a folder
   - Create new folder
   - Rename file
   - Delete file (with confirmation dialog)

3. **Text Editor Automation** (`examples/real_world/text_editor.zig`)
   - Open gedit/kate
   - Type text
   - Save file with specific name
   - Close application

4. **Multi-Application Workflow** (`examples/real_world/multi_app_workflow.zig`)
   - Copy data from web browser
   - Paste into spreadsheet application
   - Save spreadsheet

5. **Error Handling Scenarios** (`examples/real_world/error_handling.zig`)
   - Handle "element not found" gracefully
   - Implement retry logic
   - Screenshot on failure for debugging

**Validation Process:**

```python
# tests/playwright/test_real_world.py
# Use Playwright to set up scenarios, then run Zikuli automation

def test_browser_form_fill():
    # 1. Playwright opens browser to test form page
    # 2. Run Zikuli automation to fill the form
    # 3. Playwright verifies form was submitted correctly
    pass

def test_file_operations():
    # 1. Create test directory structure
    # 2. Run Zikuli file manager automation
    # 3. Verify files were created/renamed/moved correctly
    pass
```

**Success Criteria for Phase 10:**
- [ ] At least 3 different real applications automated successfully
- [ ] Each automation runs end-to-end without manual intervention
- [ ] Error scenarios are handled gracefully
- [ ] Performance is acceptable (< 5s per action)
- [ ] Screenshots captured at key steps for debugging
- [ ] Works on fresh Ubuntu/Mint installation

**Paranoid Review Focus**: Does Zikuli actually WORK in the real world? Not just tests!

**Commit**: `feat: add real-world automation examples`

---

## Validation-Driven Development Process

### After Each Phase

1. **Unit Tests** (automated):
   ```bash
   ~/.zig/zig build test
   ```

2. **Manual Validation** (visual confirmation):
   - Run the specific test binary for the phase
   - Verify behavior matches expectation
   - Document any discrepancies

3. **Paranoid Reviewer Agent**:
   - Spawn agent to review:
     - Code correctness vs Sikuli behavior
     - Memory safety issues
     - Error handling completeness
     - Edge cases
     - Security issues
     - Platform-specific concerns
   - Fix any issues raised
   - Spawn verification agent to confirm fixes

4. **Commit**:
   - Small, atomic commit for the phase
   - Include test results in commit message

### Paranoid Reviewer Agent Prompt Template

```
You are a paranoid code reviewer for the Zikuli project (Sikuli re-implementation in Zig).

Review Phase X: [Phase Name]

Files to review:
- [list files]

Check for:
1. CORRECTNESS: Does this match Sikuli's behavior? Reference SikuliX source at /tmp/temp-github-repos/SikuliX1/
2. MEMORY SAFETY: Any leaks, use-after-free, buffer overflows?
3. ERROR HANDLING: All error paths handled? Errors propagated correctly?
4. EDGE CASES: Zero sizes, negative coords, null pointers, empty arrays?
5. SECURITY: Any injection risks, unsafe operations?
6. PLATFORM: Will this work on different Linux distros? X11 vs Wayland?
7. PERFORMANCE: Any obvious inefficiencies?
8. IDIOMS: Is this idiomatic Zig? Using std lib correctly?

For each issue found, provide:
- Severity: CRITICAL / HIGH / MEDIUM / LOW
- Location: file:line
- Issue: Description
- Fix: Suggested fix
```

---

## Technical Dependencies

### Required System Libraries (Linux)

```bash
# Install on Ubuntu/Mint
sudo apt-get install \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-image0-dev \
    libxcb-xtest0-dev \
    libopencv-dev \
    libtesseract-dev \
    libleptonica-dev
```

### Zig Dependencies (build.zig.zon)

```zig
.{
    .name = "zikuli",
    .version = "0.1.0",
    .dependencies = .{
        .zigcv = .{
            .url = "https://github.com/ryoppippi/zigcv/archive/...",
            .hash = "...",
        },
        .stb = .{
            .url = "...",  // For image loading
        },
    },
}
```

---

## Commit Strategy

All commits follow conventional commits format:

```
feat: <description>     # New feature
fix: <description>      # Bug fix
test: <description>     # Test additions
docs: <description>     # Documentation
refactor: <description> # Code restructure
```

Each phase = 1-2 commits. Maximum ~20 commits for full implementation.

---

## Success Criteria

The implementation is complete when:

1. [ ] All 10 phases complete with passing tests
2. [ ] Example automation script successfully:
   - Captures screen
   - Finds image pattern
   - Clicks on match
   - Types text
3. [ ] No memory leaks (verified with valgrind)
4. [ ] Works on fresh Ubuntu/Mint installation
5. [ ] README with usage instructions exists
6. [ ] **REAL-WORLD VALIDATION**: At least 3 actual applications automated end-to-end
   - Web browser (form fill, navigation)
   - File manager (create/rename/delete files)
   - Text editor (type, save, close)

---

## User Decisions (Confirmed)

| Decision | Choice |
|----------|--------|
| **OCR** | Include in initial implementation (Phase 8) |
| **Display Server** | X11 only (matches Sikuli behavior) |
| **Test Data** | Use synthetic test images |
| **Still-there optimization** | Implement (cache last match location) |

---

## Source Code Reference

All analysis based on:
- **SikuliX1 (Java)**: `/tmp/temp-github-repos/SikuliX1/`
- **sikuli-original (C++)**: `/tmp/temp-github-repos/sikuli-original/sikuli-script/src/main/native/`

Key files to reference during implementation:
- `sikuli-original/.../finder.cpp` - TemplateFinder algorithm
- `sikuli-original/.../pyramid-template-matcher.cpp` - Coarse-to-fine matching
- `SikuliX1/API/.../Finder.java` - Modern Java matching logic
- `SikuliX1/API/.../Mouse.java` - Mouse control and threading
- `SikuliX1/API/.../RobotDesktop.java` - Platform interaction

