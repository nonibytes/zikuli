//! Real-World Comprehensive Web Test
//!
//! This test demonstrates Zikuli finding and interacting with actual UI elements:
//! 1. Button clicks
//! 2. Double-click
//! 3. Drag and drop
//! 4. Scroll

const std = @import("std");
const zikuli = @import("zikuli");

const Image = zikuli.Image;
const Screen = zikuli.Screen;
const Finder = zikuli.Finder;
const Mouse = zikuli.Mouse;

/// Button color definitions (matching the HTML)
const ButtonColor = struct {
    r: u8,
    g: u8,
    b: u8,
    name: []const u8,
};

const RED_BUTTON = ButtonColor{ .r = 255, .g = 100, .b = 50, .name = "RED" };
const GREEN_BUTTON = ButtonColor{ .r = 50, .g = 200, .b = 100, .name = "GREEN" };
const BLUE_BUTTON = ButtonColor{ .r = 50, .g = 100, .b = 255, .name = "BLUE" };
const PURPLE_DBLCLICK = ButtonColor{ .r = 153, .g = 50, .b = 204, .name = "PURPLE (double-click)" };
const ORANGE_DRAG = ButtonColor{ .r = 255, .g = 153, .b = 51, .name = "ORANGE (draggable)" };

/// Create a solid color template image for finding elements
fn createColorTemplate(allocator: std.mem.Allocator, color: ButtonColor, size: u32) !Image {
    var img = try Image.init(allocator, size, size, .BGRA);

    var y: u32 = 0;
    while (y < size) : (y += 1) {
        var x: u32 = 0;
        while (x < size) : (x += 1) {
            img.setPixel(x, y, color.r, color.g, color.b, 255);
        }
    }

    return img;
}

/// Find an element by its color
fn findElement(allocator: std.mem.Allocator, screen_image: *const Image, color: ButtonColor, template_size: u32) !?struct { x: i32, y: i32, score: f64 } {
    var template = try createColorTemplate(allocator, color, template_size);
    defer template.deinit();

    var finder = Finder.init(allocator, screen_image);
    defer finder.deinit();

    finder.setSimilarity(0.75);

    if (finder.find(&template)) |match| {
        const target = match.getTarget();
        return .{ .x = target.x, .y = target.y, .score = match.score };
    }
    return null;
}

/// Capture screen and convert to Image
fn captureScreen(allocator: std.mem.Allocator, screen: *Screen) !Image {
    var captured = try screen.capture();
    defer captured.deinit();
    return try Image.fromCapture(allocator, captured);
}

/// Query server for event stats
fn getServerStats(allocator: std.mem.Allocator) ?ServerStats {
    // Use curl to query the server
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "http://localhost:8765/stats" },
    }) catch return null;

    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    // Check if successful (exit code 0)
    if (result.term == .Exited and result.term.Exited == 0) {
        const stdout = result.stdout;

        // Simple JSON parsing for our stats
        var stats = ServerStats{};

        if (std.mem.indexOf(u8, stdout, "\"clicks\":")) |idx| {
            const start = idx + 9;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                stats.clicks = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }
        if (std.mem.indexOf(u8, stdout, "\"drops\":")) |idx| {
            const start = idx + 8;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                stats.drops = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }
        if (std.mem.indexOf(u8, stdout, "\"double_clicks\":")) |idx| {
            const start = idx + 16;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                stats.double_clicks = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }
        if (std.mem.indexOf(u8, stdout, "\"scrolls\":")) |idx| {
            const start = idx + 10;
            if (std.mem.indexOfAny(u8, stdout[start..], ",}")) |end| {
                stats.scrolls = std.fmt.parseInt(u32, std.mem.trim(u8, stdout[start..][0..end], " "), 10) catch 0;
            }
        }

        return stats;
    }

    return null;
}

/// Clear server events
fn clearServerEvents(allocator: std.mem.Allocator) void {
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &.{ "curl", "-s", "http://localhost:8765/clear" },
    }) catch return;
    allocator.free(result.stdout);
    allocator.free(result.stderr);
}

const ServerStats = struct {
    clicks: u32 = 0,
    drops: u32 = 0,
    double_clicks: u32 = 0,
    scrolls: u32 = 0,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     Zikuli Comprehensive Web Test                        ║\n", .{});
    std.debug.print("║     Testing: Click, Double-Click, Drag/Drop, Scroll      ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    std.debug.print("Make sure the test webpage is visible on screen.\n", .{});
    std.debug.print("Starting in 2 seconds...\n\n", .{});
    std.Thread.sleep(2 * std.time.ns_per_s);

    // Clear server events
    clearServerEvents(allocator);

    var screen = try Screen.virtual(allocator);
    defer screen.deinit();

    var results = TestResults{};

    // =====================================================================
    // TEST 1: BUTTON CLICKS
    // =====================================================================
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 1: Button Clicks\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    var screen_image = try captureScreen(allocator, &screen);
    defer screen_image.deinit();

    // Click RED button
    if (try findElement(allocator, &screen_image, RED_BUTTON, 20)) |el| {
        std.debug.print("  ✓ Found RED button at ({}, {}) score={d:.2}\n", .{ el.x, el.y, el.score });
        try Mouse.clickAt(el.x, el.y, .left);
        std.Thread.sleep(200 * std.time.ns_per_ms);
        results.clicks += 1;
    } else {
        std.debug.print("  ✗ RED button not found\n", .{});
    }

    // Click GREEN button
    var screen_image2 = try captureScreen(allocator, &screen);
    defer screen_image2.deinit();

    if (try findElement(allocator, &screen_image2, GREEN_BUTTON, 20)) |el| {
        std.debug.print("  ✓ Found GREEN button at ({}, {}) score={d:.2}\n", .{ el.x, el.y, el.score });
        try Mouse.clickAt(el.x, el.y, .left);
        std.Thread.sleep(200 * std.time.ns_per_ms);
        results.clicks += 1;
    } else {
        std.debug.print("  ✗ GREEN button not found\n", .{});
    }

    // Click BLUE button
    var screen_image3 = try captureScreen(allocator, &screen);
    defer screen_image3.deinit();

    if (try findElement(allocator, &screen_image3, BLUE_BUTTON, 20)) |el| {
        std.debug.print("  ✓ Found BLUE button at ({}, {}) score={d:.2}\n", .{ el.x, el.y, el.score });
        try Mouse.clickAt(el.x, el.y, .left);
        std.Thread.sleep(200 * std.time.ns_per_ms);
        results.clicks += 1;
    } else {
        std.debug.print("  ✗ BLUE button not found\n", .{});
    }

    // =====================================================================
    // TEST 2: DOUBLE-CLICK
    // =====================================================================
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 2: Double-Click\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    var screen_image4 = try captureScreen(allocator, &screen);
    defer screen_image4.deinit();

    if (try findElement(allocator, &screen_image4, PURPLE_DBLCLICK, 25)) |el| {
        std.debug.print("  ✓ Found PURPLE double-click target at ({}, {}) score={d:.2}\n", .{ el.x, el.y, el.score });
        try Mouse.moveTo(el.x, el.y);
        try Mouse.doubleClick(.left);
        std.Thread.sleep(300 * std.time.ns_per_ms);
        results.double_clicks += 1;
    } else {
        std.debug.print("  ✗ PURPLE double-click target not found\n", .{});
    }

    // =====================================================================
    // TEST 3: DRAG AND DROP
    // =====================================================================
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 3: Drag and Drop\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    var screen_image5 = try captureScreen(allocator, &screen);
    defer screen_image5.deinit();

    // Find the orange draggable element
    // First, use findAll to get all orange matches and pick the one below the purple target
    var template_orange = try createColorTemplate(allocator, ORANGE_DRAG, 40);
    defer template_orange.deinit();

    var finder_orange = Finder.init(allocator, &screen_image5);
    defer finder_orange.deinit();
    finder_orange.setSimilarity(0.85);

    // Find all orange matches
    const orange_matches = try finder_orange.findAll(&template_orange);
    defer allocator.free(orange_matches);

    std.debug.print("  Found {} orange matches\n", .{orange_matches.len});

    // Find the one that's below y=400 (should be in the drag/drop section)
    var best_drag: ?struct { x: i32, y: i32, score: f64 } = null;
    for (orange_matches) |match| {
        const target = match.getTarget();
        std.debug.print("    - Orange at ({}, {}) score={d:.2}\n", .{ target.x, target.y, match.score });
        if (target.y > 400) { // Must be below the double-click section
            if (best_drag == null or match.score > best_drag.?.score) {
                best_drag = .{ .x = target.x, .y = target.y, .score = match.score };
            }
        }
    }

    if (best_drag) |drag_el| {
        std.debug.print("  ✓ Selected ORANGE draggable at ({}, {}) score={d:.2}\n", .{ drag_el.x, drag_el.y, drag_el.score });

        // Drop zone is approximately 240px to the right
        const drop_x = drag_el.x + 240;
        const drop_y = drag_el.y;

        std.debug.print("  → Dragging from ({}, {}) to ({}, {})\n", .{ drag_el.x, drag_el.y, drop_x, drop_y });

        // Manual drag with delays for webpage to register properly
        try Mouse.moveTo(drag_el.x, drag_el.y);
        std.Thread.sleep(300 * std.time.ns_per_ms);

        try Mouse.buttonDown(.left);
        std.Thread.sleep(300 * std.time.ns_per_ms);

        // Move slowly to destination in steps
        var step: i32 = 0;
        while (step <= 5) : (step += 1) {
            const curr_x = drag_el.x + @divFloor((drop_x - drag_el.x) * step, 5);
            try Mouse.moveTo(curr_x, drop_y);
            std.Thread.sleep(50 * std.time.ns_per_ms);
        }

        std.Thread.sleep(200 * std.time.ns_per_ms);

        // Release over drop zone
        try Mouse.buttonUp(.left);
        std.Thread.sleep(500 * std.time.ns_per_ms);

        results.drags += 1;
    } else {
        std.debug.print("  ✗ ORANGE draggable not found in drag section (y > 400)\n", .{});
    }

    // =====================================================================
    // TEST 4: SCROLL
    // =====================================================================
    std.debug.print("\n═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("TEST 4: Scroll\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    // The scroll container is below the drag section
    // We need to find the scroll container border color (#888 = gray)
    // and click inside it to focus, then scroll
    var screen_image6 = try captureScreen(allocator, &screen);
    defer screen_image6.deinit();

    // Look for a light purple/pink colored item in the scroll container
    // The scroll items alternate between light blue (#e0e0ff) and light pink (#ffe0e0)
    const SCROLL_ITEM_PINK = ButtonColor{ .r = 255, .g = 224, .b = 224, .name = "SCROLL ITEM" };

    if (try findElement(allocator, &screen_image6, SCROLL_ITEM_PINK, 15)) |scroll_el| {
        std.debug.print("  ✓ Found scroll item at ({}, {})\n", .{ scroll_el.x, scroll_el.y });

        // First click to focus the scroll container
        std.debug.print("  → Clicking to focus scroll container...\n", .{});
        try Mouse.clickAt(scroll_el.x, scroll_el.y, .left);
        std.Thread.sleep(200 * std.time.ns_per_ms);

        // Now scroll down
        std.debug.print("  → Scrolling down...\n", .{});
        try Mouse.wheelDown(5);
        std.Thread.sleep(400 * std.time.ns_per_ms);
        results.scrolls += 1;

        // Scroll up
        std.debug.print("  → Scrolling up...\n", .{});
        try Mouse.wheelUp(3);
        std.Thread.sleep(400 * std.time.ns_per_ms);
        results.scrolls += 1;
    } else {
        std.debug.print("  ✗ Scroll container not found, trying fixed position\n", .{});
        // Try a fixed position if color detection fails
        // Approximate position based on the drag section being around y=600
        try Mouse.clickAt(200, 750, .left); // Click to focus
        std.Thread.sleep(200 * std.time.ns_per_ms);

        std.debug.print("  → Scrolling down at fixed position...\n", .{});
        try Mouse.wheelDown(5);
        std.Thread.sleep(400 * std.time.ns_per_ms);
        results.scrolls += 1;
    }

    // =====================================================================
    // RESULTS SUMMARY
    // =====================================================================
    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║                    TEST RESULTS                          ║\n", .{});
    std.debug.print("╠══════════════════════════════════════════════════════════╣\n", .{});
    std.debug.print("║  Button Clicks:    {}/3                                  ║\n", .{results.clicks});
    std.debug.print("║  Double-Clicks:    {}/1                                  ║\n", .{results.double_clicks});
    std.debug.print("║  Drag Operations:  {}/1                                  ║\n", .{results.drags});
    std.debug.print("║  Scroll Operations: {}/2                                  ║\n", .{results.scrolls});
    std.debug.print("╠══════════════════════════════════════════════════════════╣\n", .{});

    const total = results.clicks + results.double_clicks + results.drags + results.scrolls;
    const max_total: u32 = 7;

    if (total >= max_total) {
        std.debug.print("║  ✓ ALL TESTS PASSED! ({}/{})                            ║\n", .{ total, max_total });
    } else if (total >= 5) {
        std.debug.print("║  ⚠ MOSTLY PASSED ({}/{})                                ║\n", .{ total, max_total });
    } else {
        std.debug.print("║  ✗ SOME TESTS FAILED ({}/{})                            ║\n", .{ total, max_total });
    }
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});

    // =====================================================================
    // SERVER VERIFICATION
    // =====================================================================
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("SERVER-SIDE VERIFICATION\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});

    // Wait a moment for any pending events to be processed
    std.Thread.sleep(500 * std.time.ns_per_ms);

    if (getServerStats(allocator)) |stats| {
        std.debug.print("  Server received events:\n", .{});
        std.debug.print("    Clicks:        {} (expected: 3)\n", .{stats.clicks});
        std.debug.print("    Double-Clicks: {} (expected: 1)\n", .{stats.double_clicks});
        std.debug.print("    Drops:         {} (expected: 1)\n", .{stats.drops});
        std.debug.print("    Scrolls:       {} (expected: 2+)\n", .{stats.scrolls});
        std.debug.print("\n", .{});

        var verified: u32 = 0;
        var failed: u32 = 0;

        if (stats.clicks >= 3) {
            std.debug.print("  ✓ Clicks VERIFIED by server\n", .{});
            verified += 1;
        } else {
            std.debug.print("  ✗ Clicks NOT verified (got {}, expected 3)\n", .{stats.clicks});
            failed += 1;
        }

        if (stats.double_clicks >= 1) {
            std.debug.print("  ✓ Double-click VERIFIED by server\n", .{});
            verified += 1;
        } else {
            std.debug.print("  ✗ Double-click NOT verified (got {}, expected 1)\n", .{stats.double_clicks});
            failed += 1;
        }

        if (stats.drops >= 1) {
            std.debug.print("  ✓ Drag/Drop VERIFIED by server\n", .{});
            verified += 1;
        } else {
            std.debug.print("  ✗ Drag/Drop NOT verified (got {}, expected 1)\n", .{stats.drops});
            failed += 1;
        }

        if (stats.scrolls >= 1) {
            std.debug.print("  ✓ Scroll VERIFIED by server\n", .{});
            verified += 1;
        } else {
            std.debug.print("  ✗ Scroll NOT verified (got {}, expected 1+)\n", .{stats.scrolls});
            failed += 1;
        }

        std.debug.print("\n", .{});
        std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
        if (failed == 0) {
            std.debug.print("║  ✓ ALL EVENTS VERIFIED BY SERVER! ({}/4)                ║\n", .{verified});
        } else {
            std.debug.print("║  ✗ VERIFICATION FAILED ({}/4 verified)                  ║\n", .{verified});
        }
        std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    } else {
        std.debug.print("  ⚠ Could not connect to server for verification.\n", .{});
        std.debug.print("  Make sure test_server.py is running on port 8765.\n", .{});
    }
}

const TestResults = struct {
    clicks: u32 = 0,
    double_clicks: u32 = 0,
    drags: u32 = 0,
    scrolls: u32 = 0,
};

test "web: comprehensive test" {
    // This test requires a browser to be open with the test page
    const allocator = std.testing.allocator;

    var screen = Screen.virtual(allocator) catch |err| {
        if (err == error.ConnectionFailed) {
            std.debug.print("No X11 display - skipping web test\n", .{});
            return;
        }
        return err;
    };
    defer screen.deinit();

    std.debug.print("Web comprehensive test ready\n", .{});
}
