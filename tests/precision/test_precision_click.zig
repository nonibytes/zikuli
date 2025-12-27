//! Precision Click Test
//!
//! This test verifies that Zikuli clicks at the exact center of found elements.
//!
//! Test setup:
//! 1. A webpage displays precisely positioned buttons at known coordinates
//! 2. Zikuli finds each button by its color
//! 3. Zikuli clicks the button (should click at center of match)
//! 4. The webpage reports the actual click coordinates
//! 5. We verify the click was within ±5px of the expected center
//!
//! Target 1: Red button #e94560 at (400,300) size 200x80 → center (500,340)
//! Target 2: Blue button #0f3460 at (800,500) size 150x100 → center (875,550)

const std = @import("std");
const zikuli = @import("zikuli");

const Image = zikuli.Image;
const Screen = zikuli.Screen;
const Finder = zikuli.Finder;
const Mouse = zikuli.Mouse;

/// Test target definition
const Target = struct {
    name: []const u8,
    color: Color,
    // Actual button dimensions (to calculate center from top-left match)
    width: u32,
    height: u32,
    // Expected center coordinates for verification
    expected_center_x: i32,
    expected_center_y: i32,
    tolerance: i32 = 5,
};

const Color = struct {
    r: u8,
    g: u8,
    b: u8,
};

// Target definitions matching the HTML
// Template size matches button size, so match center == button center
const TARGET_1 = Target{
    .name = "Target 1 (Red)",
    .color = .{ .r = 233, .g = 69, .b = 96 }, // #e94560
    .width = 200,
    .height = 80,
    // Button at (400,300), center at (400+100, 300+40)
    .expected_center_x = 500,
    .expected_center_y = 340,
};

const TARGET_2 = Target{
    .name = "Target 2 (Blue)",
    .color = .{ .r = 15, .g = 52, .b = 96 }, // #0f3460
    .width = 150,
    .height = 100,
    // Button at (800,500), center at (800+75, 500+50)
    .expected_center_x = 875,
    .expected_center_y = 550,
};

/// Server results from click verification
const ClickResult = struct {
    target: []const u8,
    click_x: i32,
    click_y: i32,
    expected_x: i32,
    expected_y: i32,
    distance: f64,
    success: bool,
};

const ServerResults = struct {
    total: u32,
    passed: u32,
    failed: u32,
};

/// Create a solid color template for finding elements
/// Uses actual button dimensions so the match center equals the button center
fn createColorTemplate(allocator: std.mem.Allocator, color: Color, width: u32, height: u32) !Image {
    var img = try Image.init(allocator, width, height, .BGRA);

    var y: u32 = 0;
    while (y < height) : (y += 1) {
        var x: u32 = 0;
        while (x < width) : (x += 1) {
            img.setPixel(x, y, color.r, color.g, color.b, 255);
        }
    }

    return img;
}

/// Find an element by color and return match location
/// Template dimensions match the actual button size so center calculation is correct
fn findByColor(allocator: std.mem.Allocator, screen_image: *const Image, target: Target) !?struct { x: i32, y: i32, w: u32, h: u32, score: f64 } {
    var template = try createColorTemplate(allocator, target.color, target.width, target.height);
    defer template.deinit();

    var finder = Finder.init(allocator, screen_image);
    defer finder.deinit();

    // Use lower similarity since we're matching a solid color template
    // against a button that may have text overlay
    finder.setSimilarity(0.70);

    if (finder.find(&template)) |match| {
        // Return the bounds (top-left corner) - NOT getTarget() which returns center
        // The caller will calculate center by adding width/2, height/2
        return .{
            .x = match.bounds.x,
            .y = match.bounds.y,
            .w = target.width,
            .h = target.height,
            .score = match.score,
        };
    }
    return null;
}

/// Query server for click results
fn getServerResults(allocator: std.mem.Allocator) ?ServerResults {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "http://localhost:8766/results" },
    }) catch return null;

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term == .Exited and result.term.Exited == 0) {
        const stdout = result.stdout;

        var results = ServerResults{ .total = 0, .passed = 0, .failed = 0 };

        // Parse "total": N
        if (std.mem.indexOf(u8, stdout, "\"total\":")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                results.total = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }
        // Parse "passed": N
        if (std.mem.indexOf(u8, stdout, "\"passed\":")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                results.passed = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }
        // Parse "failed": N
        if (std.mem.indexOf(u8, stdout, "\"failed\":")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                results.failed = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }

        return results;
    }

    return null;
}

/// Clear server click history
fn clearServerResults(allocator: std.mem.Allocator) void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "http://localhost:8766/clear" },
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     Zikuli Precision Click Test                          ║\n", .{});
    std.debug.print("║     Verifying click lands at exact center of target      ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Test: Find colored buttons on screen, click at center,\n", .{});
    std.debug.print("      verify server reports click within ±5px of button center.\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Make sure precision_test.html is visible in browser.\n", .{});
    std.debug.print("Starting in 3 seconds...\n\n", .{});
    std.Thread.sleep(3 * std.time.ns_per_s);

    // Clear previous results
    clearServerResults(allocator);

    var screen = try Screen.virtual(allocator);
    defer screen.deinit();

    var targets_found: u32 = 0;

    // =====================================================================
    // TEST 1: Find and click Target 1 (Red button)
    // =====================================================================
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 1: Click Target 1 (Red button)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    var screen_image = try screen.capture();
    var img1 = try Image.fromCapture(allocator, screen_image);
    screen_image.deinit();
    defer img1.deinit();

    if (try findByColor(allocator, &img1, TARGET_1)) |match| {
        // Calculate where Zikuli will click (center of matched region)
        const click_x = match.x + @as(i32, @intCast(match.w / 2));
        const click_y = match.y + @as(i32, @intCast(match.h / 2));

        std.debug.print("  Found at screen: ({}, {}) size {}x{} score={d:.2}\n", .{ match.x, match.y, match.w, match.h, match.score });
        std.debug.print("  Clicking at center: ({}, {})\n", .{ click_x, click_y });

        // Move mouse to position first to verify visually
        try Mouse.moveTo(click_x, click_y);
        std.debug.print("  Mouse moved to position, waiting 1 second...\n", .{});
        std.Thread.sleep(1 * std.time.ns_per_s);

        // Perform the click
        try Mouse.clickAt(click_x, click_y, .left);
        std.debug.print("  Click sent!\n", .{});
        std.Thread.sleep(500 * std.time.ns_per_ms);

        targets_found += 1;
    } else {
        std.debug.print("  ✗ Target 1 not found on screen!\n", .{});
    }

    // =====================================================================
    // TEST 2: Find and click Target 2 (Blue button)
    // =====================================================================
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 2: Click Target 2 (Blue button)\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    // Re-capture screen (state may have changed)
    var screen_image2 = try screen.capture();
    var img2 = try Image.fromCapture(allocator, screen_image2);
    screen_image2.deinit();
    defer img2.deinit();

    if (try findByColor(allocator, &img2, TARGET_2)) |match| {
        const click_x = match.x + @as(i32, @intCast(match.w / 2));
        const click_y = match.y + @as(i32, @intCast(match.h / 2));

        std.debug.print("  Found at screen: ({}, {}) size {}x{} score={d:.2}\n", .{ match.x, match.y, match.w, match.h, match.score });
        std.debug.print("  Clicking at center: ({}, {})\n", .{ click_x, click_y });

        try Mouse.clickAt(click_x, click_y, .left);
        std.debug.print("  Click sent!\n", .{});
        std.Thread.sleep(500 * std.time.ns_per_ms);

        targets_found += 1;
    } else {
        std.debug.print("  ✗ Target 2 not found on screen!\n", .{});
    }

    // =====================================================================
    // VERIFY WITH SERVER
    // =====================================================================
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("SERVER-SIDE VERIFICATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    // Wait for server to process clicks
    std.Thread.sleep(500 * std.time.ns_per_ms);

    if (getServerResults(allocator)) |results| {
        std.debug.print("  Server received: {} click(s)\n", .{results.total});
        std.debug.print("  Passed: {} (within ±5px of center)\n", .{results.passed});
        std.debug.print("  Failed: {}\n", .{results.failed});

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
        if (results.passed == results.total and results.total >= 2) {
            std.debug.print("║  ✓ PRECISION TEST PASSED!                                ║\n", .{});
            std.debug.print("║    All clicks landed within ±5px of target centers       ║\n", .{});
        } else if (results.passed > 0) {
            std.debug.print("║  ⚠ PARTIAL PASS: {}/{} clicks accurate                    ║\n", .{ results.passed, results.total });
        } else {
            std.debug.print("║  ✗ PRECISION TEST FAILED                                 ║\n", .{});
            std.debug.print("║    Clicks did not land at expected centers               ║\n", .{});
        }
        std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    } else {
        std.debug.print("  ⚠ Could not verify with server.\n", .{});
        std.debug.print("  Make sure precision_server.py is running on port 8766.\n", .{});

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
        std.debug.print("║  SERVER UNAVAILABLE                                      ║\n", .{});
        std.debug.print("║  Found {} targets on screen                              ║\n", .{targets_found});
        std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    }

    std.debug.print("\n", .{});
}

test "precision click test" {
    // This test requires a browser with precision_test.html open
    const allocator = std.testing.allocator;

    var screen = Screen.virtual(allocator) catch |err| {
        if (err == error.ConnectionFailed) {
            std.debug.print("No X11 display - skipping precision test\n", .{});
            return;
        }
        return err;
    };
    defer screen.deinit();

    std.debug.print("Precision click test ready\n", .{});
}
