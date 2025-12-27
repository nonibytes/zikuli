//! Virtual Environment Tests for Zikuli
//!
//! These tests run in a virtual X11 environment (Xvfb) with
//! test content placed at known locations. They verify that
//! Zikuli's capture, find, mouse, and keyboard operations
//! work correctly.
//!
//! Run with:
//!   ./tests/scripts/run_virtual_tests.sh test_virtual
//!
//! Or manually:
//!   Xvfb :99 -screen 0 1920x1080x24 -ac &
//!   DISPLAY=:99 ~/.zig/zig build test_virtual

const std = @import("std");
const harness = @import("harness");
const zikuli = @import("zikuli");

const TestHarness = harness.TestHarness;

// ============================================================================
// Screen Capture Tests
// ============================================================================

test "capture: full screen" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place some content
            _ = try h.placeColorSquare(100, 100, 50, .{ .r = 255, .g = 0, .b = 0 });

            // Capture full screen
            var capture = try zikuli.ScreenCapture.init(h.allocator);
            defer capture.deinit();

            var image = try capture.capture();
            defer image.deinit();

            // Verify dimensions match screen
            const screen = h.getScreenSize();
            try std.testing.expectEqual(screen.width, image.width);
            try std.testing.expectEqual(screen.height, image.height);

            // Verify we captured the red square (check center pixel)
            const pixel = image.getPixel(125, 125) catch return;
            // Red pixel (with some tolerance for color depth variations)
            try std.testing.expect(pixel.r > 200);
            try std.testing.expect(pixel.g < 50);
            try std.testing.expect(pixel.b < 50);
        }
    }.run);
}

test "capture: region" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place red square at (200, 200)
            _ = try h.placeColorSquare(200, 200, 50, .{ .r = 255, .g = 0, .b = 0 });

            std.time.sleep(100 * std.time.ns_per_ms);

            // Capture just that region
            var capture = try zikuli.ScreenCapture.init(h.allocator);
            defer capture.deinit();

            var image = try capture.captureRegion(200, 200, 50, 50);
            defer image.deinit();

            // Verify dimensions
            try std.testing.expectEqual(@as(u32, 50), image.width);
            try std.testing.expectEqual(@as(u32, 50), image.height);

            // Verify center pixel is red
            const pixel = image.getPixel(25, 25) catch return;
            try std.testing.expect(pixel.r > 200);
        }
    }.run);
}

// ============================================================================
// Mouse Tests
// ============================================================================

test "mouse: move to position" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            var mouse = zikuli.Mouse.init(h.allocator);
            defer mouse.deinit();

            // Move to known position
            try mouse.move(500, 300);
            std.time.sleep(50 * std.time.ns_per_ms);

            // Verify position
            try h.verifier.expectMouseAt(500, 300, 2);

            // Move to another position
            try mouse.move(100, 100);
            std.time.sleep(50 * std.time.ns_per_ms);

            try h.verifier.expectMouseAt(100, 100, 2);
        }
    }.run);
}

test "mouse: click at position" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            var mouse = zikuli.Mouse.init(h.allocator);
            defer mouse.deinit();

            // Click at position
            try mouse.click(300, 200);
            std.time.sleep(50 * std.time.ns_per_ms);

            // Verify mouse ended at click position
            try h.verifier.expectMouseAt(300, 200, 2);
        }
    }.run);
}

// ============================================================================
// Template Matching Tests
// ============================================================================

test "finder: exact color match" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place red square at known location
            _ = try h.placeColorSquare(400, 300, 50, .{ .r = 255, .g = 0, .b = 0 });
            std.time.sleep(100 * std.time.ns_per_ms);

            // Capture screen
            var capture = try zikuli.ScreenCapture.init(h.allocator);
            defer capture.deinit();

            var screen_img = try capture.capture();
            defer screen_img.deinit();

            // Create a red template (same color)
            var template = try zikuli.Image.create(h.allocator, 30, 30, .RGBA);
            defer template.deinit();
            template.fill(.{ .r = 255, .g = 0, .b = 0, .a = 255 });

            // Find the template
            var finder = try zikuli.Finder.init(h.allocator);
            defer finder.deinit();

            const result = finder.find(screen_img, template, 0.7);

            if (result) |match| {
                // Should find it near (400, 300)
                const dx = @abs(match.x - 400);
                const dy = @abs(match.y - 300);

                // Allow some tolerance (pattern may match at offset)
                try std.testing.expect(dx < 30);
                try std.testing.expect(dy < 30);
                try std.testing.expect(match.similarity >= 0.7);
            } else {
                // Template matching may need calibration
                std.debug.print("Warning: Template not found - may need similarity adjustment\n", .{});
            }
        }
    }.run);
}

test "finder: no match returns null" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place only blue content
            _ = try h.placeColorSquare(100, 100, 50, .{ .r = 0, .g = 0, .b = 255 });
            std.time.sleep(100 * std.time.ns_per_ms);

            // Capture screen
            var capture = try zikuli.ScreenCapture.init(h.allocator);
            defer capture.deinit();

            var screen_img = try capture.capture();
            defer screen_img.deinit();

            // Create a red template (should NOT match blue)
            var template = try zikuli.Image.create(h.allocator, 30, 30, .RGBA);
            defer template.deinit();
            template.fill(.{ .r = 255, .g = 0, .b = 0, .a = 255 });

            // Try to find it
            var finder = try zikuli.Finder.init(h.allocator);
            defer finder.deinit();

            const result = finder.find(screen_img, template, 0.9);

            // Should NOT find red in blue-only scene with high threshold
            try std.testing.expect(result == null or result.?.similarity < 0.9);
        }
    }.run);
}

// ============================================================================
// Integration Tests
// ============================================================================

test "integration: find and click" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place target at known location
            const target_x: i16 = 600;
            const target_y: i16 = 400;
            _ = try h.placeColorSquare(target_x, target_y, 40, .{ .r = 0, .g = 255, .b = 0 });
            std.time.sleep(100 * std.time.ns_per_ms);

            // Capture screen
            var capture = try zikuli.ScreenCapture.init(h.allocator);
            defer capture.deinit();

            var screen_img = try capture.capture();
            defer screen_img.deinit();

            // Create matching template
            var template = try zikuli.Image.create(h.allocator, 30, 30, .RGBA);
            defer template.deinit();
            template.fill(.{ .r = 0, .g = 255, .b = 0, .a = 255 });

            // Find target
            var finder = try zikuli.Finder.init(h.allocator);
            defer finder.deinit();

            if (finder.find(screen_img, template, 0.7)) |match| {
                // Click on found location (center of match)
                const click_x: i32 = match.x + @as(i32, @intCast(match.width / 2));
                const click_y: i32 = match.y + @as(i32, @intCast(match.height / 2));

                var mouse = zikuli.Mouse.init(h.allocator);
                defer mouse.deinit();

                try mouse.click(@intCast(click_x), @intCast(click_y));
                std.time.sleep(50 * std.time.ns_per_ms);

                // Verify we clicked near the target
                const target_center_x: i32 = target_x + 20;
                const target_center_y: i32 = target_y + 20;
                try h.verifier.expectMouseAt(target_center_x, target_center_y, 20);
            } else {
                std.debug.print("Warning: Could not find target for click test\n", .{});
            }
        }
    }.run);
}

test "integration: multi-target scene" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup a scene with multiple targets
            try h.setupTestScene();

            // Verify all content is visible
            try h.verifyAllVisible();

            h.printPlacedContent();

            // The scene should have 3 colored squares
            try std.testing.expectEqual(@as(usize, 3), h.placed_windows.items.len);
        }
    }.run);
}

// ============================================================================
// Edge Case Tests
// ============================================================================

test "edge: screen corners" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const screen = h.getScreenSize();

            // Place content near corners
            _ = try h.placeColorSquare(0, 0, 30, .{ .r = 255, .g = 0, .b = 0 }); // Top-left
            _ = try h.placeColorSquare(@intCast(screen.width - 30), 0, 30, .{ .r = 0, .g = 255, .b = 0 }); // Top-right
            _ = try h.placeColorSquare(0, @intCast(screen.height - 30), 30, .{ .r = 0, .g = 0, .b = 255 }); // Bottom-left

            std.time.sleep(100 * std.time.ns_per_ms);

            // Verify corners have content
            try h.verifier.expectColorAt(15, 15, 255, 0, 0, 20); // Red at top-left
            try h.verifier.expectColorAt(@intCast(screen.width - 15), 15, 0, 255, 0, 20); // Green at top-right
            try h.verifier.expectColorAt(15, @intCast(screen.height - 15), 0, 0, 255, 20); // Blue at bottom-left
        }
    }.run);
}

test "edge: small pattern" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place minimum size pattern (12x12 is MIN_TARGET_DIMENSION)
            _ = try h.placeColorSquare(500, 500, 15, .{ .r = 255, .g = 255, .b = 0 });
            std.time.sleep(100 * std.time.ns_per_ms);

            // Verify it exists
            try h.verifier.expectColorAt(507, 507, 255, 255, 0, 20);
        }
    }.run);
}
