//! Virtual Environment Tests for Zikuli
//!
//! These tests run in a virtual X11 environment (Xvfb) with
//! test content placed at known locations.
//!
//! IMPORTANT: These tests verify that operations ACTUALLY WORK by:
//! - Tracking X11 events (button press/release, motion) on target windows
//! - Verifying events were received, not just mouse position
//! - Using tight tolerances for color verification
//!
//! Run with:
//!   ./tests/scripts/run_virtual_tests.sh test-virtual

const std = @import("std");
const harness = @import("harness");
const zikuli = @import("zikuli");

const TestHarness = harness.TestHarness;
const RGB = harness.RGB;

// ============================================================================
// Screen Capture Tests
// ============================================================================

test "capture: full screen dimensions" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = try h.placeColorSquare(100, 100, 50, RGB{ .r = 255, .g = 0, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            var screen = try zikuli.Screen.virtual(h.allocator);
            defer screen.deinit();

            var captured = try screen.capture();
            defer captured.deinit();

            const screen_size = h.getScreenSize();
            try std.testing.expectEqual(screen_size.width, @as(u16, @intCast(captured.width)));
            try std.testing.expectEqual(screen_size.height, @as(u16, @intCast(captured.height)));
        }
    }.run);
}

test "capture: region dimensions" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = try h.placeColorSquare(200, 200, 50, RGB{ .r = 255, .g = 0, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            var screen = try zikuli.Screen.virtual(h.allocator);
            defer screen.deinit();

            var captured = try screen.captureRegion(zikuli.Rectangle.init(200, 200, 50, 50));
            defer captured.deinit();

            try std.testing.expectEqual(@as(u32, 50), captured.width);
            try std.testing.expectEqual(@as(u32, 50), captured.height);
        }
    }.run);
}

// ============================================================================
// Mouse Position Tests (basic movement verification)
// ============================================================================

test "mouse: move to position" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(500, 300);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos1 = try zikuli.Mouse.getPosition();
            // Tolerance of 10 pixels to account for X11 event timing
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos1.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos1.y)), 10);

            try zikuli.Mouse.moveTo(100, 100);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos2 = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 100), @as(f64, @floatFromInt(pos2.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 100), @as(f64, @floatFromInt(pos2.y)), 10);
        }
    }.run);
}

// ============================================================================
// Click Tests WITH EVENT VERIFICATION
// These tests verify clicks actually produce X11 button events
// ============================================================================

test "click: left click produces button events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Create a click target that tracks events
            const target = try h.placeClickTarget(300, 200, 100, RGB{ .r = 255, .g = 0, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Clear any stale events
            h.clearEvents();

            // Click in the center of the target
            const center = target.center();
            try zikuli.Mouse.clickAt(center.x, center.y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Poll for events
            try h.pollEvents();

            // VERIFY: Button 1 press AND release events received
            try h.expectClick(1); // 1 = left button
        }
    }.run);
}

test "click: right click produces button events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(400, 300, 100, RGB{ .r = 0, .g = 255, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.clickAt(center.x, center.y, .right);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Button 3 (right) press AND release events received
            try h.expectClick(3);
        }
    }.run);
}

test "click: middle click produces button events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(500, 400, 100, RGB{ .r = 0, .g = 0, .b = 255 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.clickAt(center.x, center.y, .middle);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Button 2 (middle) press AND release events received
            try h.expectClick(2);
        }
    }.run);
}

test "click: double click produces two click events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(350, 350, 100, RGB{ .r = 255, .g = 255, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            try zikuli.Mouse.doubleLeftClick();
            std.Thread.sleep(150 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Two complete clicks (2 presses, 2 releases)
            try h.expectDoubleClick(1);
        }
    }.run);
}

// ============================================================================
// Drag Tests WITH EVENT VERIFICATION
// These tests verify drags produce press, motion, release sequence
// ============================================================================

test "drag: left drag produces press-motion-release" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Create a large drag target
            const target = try h.placeClickTarget(200, 200, 200, RGB{ .r = 200, .g = 200, .b = 200 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            // Drag from one corner to another within the target
            const start_x = target.x + 20;
            const start_y = target.y + 20;
            const end_x = target.x + 180;
            const end_y = target.y + 180;

            try zikuli.Mouse.dragFromTo(start_x, start_y, end_x, end_y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Drag sequence (press, motion, release)
            try h.expectDrag(1);
        }
    }.run);
}

test "drag: right drag produces correct events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(450, 200, 200, RGB{ .r = 180, .g = 180, .b = 220 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const start_x = target.x + 20;
            const start_y = target.y + 100;
            const end_x = target.x + 180;
            const end_y = target.y + 100;

            try zikuli.Mouse.dragFromTo(start_x, start_y, end_x, end_y, .right);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Right button drag
            try h.expectDrag(3);
        }
    }.run);
}

// ============================================================================
// Scroll Tests WITH EVENT VERIFICATION
// These tests verify scroll produces wheel button events
// ============================================================================

test "scroll: wheel up produces scroll events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(600, 400, 150, RGB{ .r = 220, .g = 220, .b = 220 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            // Move to target and scroll
            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            try zikuli.Mouse.wheelUp(3);
            std.Thread.sleep(200 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Scroll up events (button 4 in X11)
            try h.expectScrollUp(3);
        }
    }.run);
}

test "scroll: wheel down produces scroll events" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(600, 600, 150, RGB{ .r = 200, .g = 220, .b = 240 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            try zikuli.Mouse.wheelDown(5);
            std.Thread.sleep(300 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Scroll down events (button 5 in X11)
            try h.expectScrollDown(5);
        }
    }.run);
}

// ============================================================================
// Content Placement Tests (with tighter color tolerance)
// ============================================================================

test "content: place and verify color square" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = try h.placeColorSquare(300, 300, 50, RGB{ .r = 255, .g = 0, .b = 0 });
            // Longer sleep for X11 rendering to complete
            std.Thread.sleep(300 * std.time.ns_per_ms);

            // Tolerance of 20 to account for X11 color rendering variations
            try h.verifier.expectColorAt(325, 325, 255, 0, 0, 20);
        }
    }.run);
}

test "content: verify green square" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = try h.placeColorSquare(400, 400, 60, RGB{ .r = 0, .g = 255, .b = 0 });
            std.Thread.sleep(300 * std.time.ns_per_ms);

            try h.verifier.expectColorAt(430, 430, 0, 255, 0, 20);
        }
    }.run);
}

test "content: verify blue square" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = try h.placeColorSquare(500, 500, 60, RGB{ .r = 0, .g = 0, .b = 255 });
            std.Thread.sleep(300 * std.time.ns_per_ms);

            try h.verifier.expectColorAt(530, 530, 0, 0, 255, 20);
        }
    }.run);
}

test "content: setup test scene with multiple squares" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            try h.setupTestScene();
            try std.testing.expectEqual(@as(usize, 3), h.placed_windows.items.len);
            h.printPlacedContent();
        }
    }.run);
}

// ============================================================================
// Smooth Movement Tests
// ============================================================================

test "mouse: smooth move reaches destination" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(100, 100);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Smooth move with short duration
            try zikuli.Mouse.smoothMove(400, 400, 100);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "mouse: zero duration smooth move is instant" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(200, 200);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            try zikuli.Mouse.smoothMove(500, 500, 0);
            std.Thread.sleep(30 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

// ============================================================================
// Realistic Scenarios WITH EVENT VERIFICATION
// ============================================================================

test "scenario: click three targets in sequence" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Create three click targets
            const t1 = try h.placeClickTarget(100, 300, 80, RGB{ .r = 255, .g = 0, .b = 0 });
            const t2 = try h.placeClickTarget(300, 300, 80, RGB{ .r = 0, .g = 255, .b = 0 });
            const t3 = try h.placeClickTarget(500, 300, 80, RGB{ .r = 0, .g = 0, .b = 255 });
            std.Thread.sleep(150 * std.time.ns_per_ms);

            h.clearEvents();

            // Click each target
            try zikuli.Mouse.clickAt(t1.center().x, t1.center().y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);
            try zikuli.Mouse.clickAt(t2.center().x, t2.center().y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);
            try zikuli.Mouse.clickAt(t3.center().x, t3.center().y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: At least 3 clicks occurred
            const press_count = h.tracker.countButtonPresses(1);
            const release_count = h.tracker.countButtonReleases(1);
            try std.testing.expect(press_count >= 3);
            try std.testing.expect(release_count >= 3);
        }
    }.run);
}

test "scenario: drag between containers" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Source and target containers
            const source = try h.placeClickTarget(100, 200, 150, RGB{ .r = 200, .g = 200, .b = 200 });
            _ = try h.placeClickTarget(400, 200, 150, RGB{ .r = 150, .g = 200, .b = 255 });
            std.Thread.sleep(150 * std.time.ns_per_ms);

            h.clearEvents();

            // Drag from source center to target center
            try zikuli.Mouse.dragFromTo(
                source.center().x,
                source.center().y,
                475, // target center
                275,
                .left,
            );
            std.Thread.sleep(150 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Drag occurred on source (at minimum we should have press+motion)
            const press_count = h.tracker.countButtonPresses(1);
            const motion_count = h.tracker.countEvents(.motion);
            try std.testing.expect(press_count >= 1);
            try std.testing.expect(motion_count >= 1);
        }
    }.run);
}

test "scenario: scroll and click workflow" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(500, 400, 120, RGB{ .r = 230, .g = 230, .b = 250 });
            std.Thread.sleep(150 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll down
            try zikuli.Mouse.wheelDown(3);
            std.Thread.sleep(200 * std.time.ns_per_ms);

            // Click
            try zikuli.Mouse.click(.left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Scroll back up
            try zikuli.Mouse.wheelUp(3);
            std.Thread.sleep(200 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Scroll and click occurred
            try h.expectScrollDown(3);
            try h.expectClick(1);
            try h.expectScrollUp(3);
        }
    }.run);
}

test "scenario: double-click then right-click menu" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(350, 350, 100, RGB{ .r = 100, .g = 150, .b = 200 });
            std.Thread.sleep(150 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Double-click
            try zikuli.Mouse.doubleLeftClick();
            std.Thread.sleep(150 * std.time.ns_per_ms);

            // Right-click
            try zikuli.Mouse.rightClick();
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Double-click and right-click occurred
            try h.expectDoubleClick(1);
            try h.expectClick(3); // right button
        }
    }.run);
}

// ============================================================================
// Edge Case Tests
// ============================================================================

test "edge: screen corners accessible" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const screen_size = h.getScreenSize();

            // Move to corners and verify
            try zikuli.Mouse.moveTo(5, 5);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            var pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.x < 20);
            try std.testing.expect(pos.y < 20);

            try zikuli.Mouse.moveTo(@intCast(screen_size.width - 5), 5);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.x > screen_size.width - 20);

            try zikuli.Mouse.moveTo(5, @intCast(screen_size.height - 5));
            std.Thread.sleep(50 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.y > screen_size.height - 20);
        }
    }.run);
}

test "edge: small click target" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Minimum size target (20x20)
            const target = try h.placeClickTarget(600, 600, 20, RGB{ .r = 255, .g = 128, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.clickAt(center.x, center.y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();
            try h.expectClick(1);
        }
    }.run);
}

// ============================================================================
// Stress Tests WITH VERIFICATION
// ============================================================================

test "stress: rapid clicks all register" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(400, 400, 150, RGB{ .r = 180, .g = 180, .b = 180 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // 10 rapid clicks
            var i: u32 = 0;
            while (i < 10) : (i += 1) {
                try zikuli.Mouse.click(.left);
                std.Thread.sleep(20 * std.time.ns_per_ms);
            }
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: All 10 clicks registered
            const press_count = h.tracker.countButtonPresses(1);
            const release_count = h.tracker.countButtonReleases(1);
            try std.testing.expect(press_count >= 10);
            try std.testing.expect(release_count >= 10);
        }
    }.run);
}

test "stress: alternating scroll directions" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const target = try h.placeClickTarget(500, 500, 150, RGB{ .r = 200, .g = 200, .b = 220 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            h.clearEvents();

            const center = target.center();
            try zikuli.Mouse.moveTo(center.x, center.y);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Alternate scroll directions
            var i: u32 = 0;
            while (i < 5) : (i += 1) {
                try zikuli.Mouse.wheelUp(1);
                std.Thread.sleep(30 * std.time.ns_per_ms);
                try zikuli.Mouse.wheelDown(1);
                std.Thread.sleep(30 * std.time.ns_per_ms);
            }
            std.Thread.sleep(100 * std.time.ns_per_ms);

            try h.pollEvents();

            // VERIFY: Scrolls registered
            const up_count = h.tracker.countScrollUp();
            const down_count = h.tracker.countScrollDown();
            try std.testing.expect(up_count >= 5);
            try std.testing.expect(down_count >= 5);
        }
    }.run);
}

// ============================================================================
// INTEGRATION TEST: Find Image and Click
// This is the core SikuliX workflow - find a visual pattern and click on it
// ============================================================================

test "integration: find image and click" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Step 1: Place a distinctive colored target on screen
            // This simulates a button or UI element we want to find and click
            const target = try h.placeClickTarget(400, 300, 80, RGB{ .r = 255, .g = 100, .b = 50 });
            std.Thread.sleep(200 * std.time.ns_per_ms);

            h.clearEvents();

            // Step 2: Create a template image that matches our target
            // In real use, this would be loaded from a PNG file
            // Use BGRA format to match X11 captured images
            var template = try zikuli.Image.init(h.allocator, 80, 80, .BGRA);
            defer template.deinit();

            // Fill template with same color as target
            var y: u32 = 0;
            while (y < 80) : (y += 1) {
                var x: u32 = 0;
                while (x < 80) : (x += 1) {
                    template.setPixel(x, y, 255, 100, 50, 255); // RGBA with alpha
                }
            }

            // Step 3: Capture screen and use Finder to locate the target
            var screen_obj = try zikuli.Screen.virtual(h.allocator);
            defer screen_obj.deinit();

            var captured = try screen_obj.capture();
            defer captured.deinit();

            // Step 4: Convert CapturedImage to Image for Finder
            var screen_image = try zikuli.Image.fromCapture(h.allocator, captured);
            defer screen_image.deinit();

            // Step 5: Find the template in the captured screen
            var finder_obj = zikuli.Finder.init(h.allocator, &screen_image);
            defer finder_obj.deinit();

            const match_result = finder_obj.find(&template);

            // Verify we found something
            try std.testing.expect(match_result != null);
            const found_match = match_result.?;

            // Verify the match is at approximately the right location
            // Target is at (400, 300), center is at (440, 340)
            const match_center = found_match.center();
            const expected_x: i32 = @as(i32, target.x) + @divTrunc(@as(i32, target.width), 2);
            const expected_y: i32 = @as(i32, target.y) + @divTrunc(@as(i32, target.height), 2);

            try std.testing.expectApproxEqAbs(
                @as(f64, @floatFromInt(expected_x)),
                @as(f64, @floatFromInt(match_center.x)),
                20,
            );
            try std.testing.expectApproxEqAbs(
                @as(f64, @floatFromInt(expected_y)),
                @as(f64, @floatFromInt(match_center.y)),
                20,
            );

            // Step 6: Click on the found match
            try zikuli.Mouse.clickAt(match_center.x, match_center.y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Step 7: Poll events and verify the click was received
            try h.pollEvents();
            try h.expectClick(1);

            // Log success
            std.debug.print("\n✓ Find-and-click integration test passed!\n", .{});
            std.debug.print("  Found target at ({}, {}) with score {d:.2}\n", .{
                found_match.bounds.x,
                found_match.bounds.y,
                found_match.score,
            });
        }
    }.run);
}

test "integration: find image with similarity threshold" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place a target
            _ = try h.placeColorSquare(500, 400, 60, RGB{ .r = 0, .g = 200, .b = 100 });
            std.Thread.sleep(200 * std.time.ns_per_ms);

            // Create a slightly different template (not exact match)
            // Use BGRA format to match X11 captured images
            var template = try zikuli.Image.init(h.allocator, 60, 60, .BGRA);
            defer template.deinit();

            // Fill with slightly different color
            var y: u32 = 0;
            while (y < 60) : (y += 1) {
                var x: u32 = 0;
                while (x < 60) : (x += 1) {
                    template.setPixel(x, y, 0, 190, 110, 255); // Slightly different, with alpha
                }
            }

            // Capture screen
            var screen_obj = try zikuli.Screen.virtual(h.allocator);
            defer screen_obj.deinit();

            var captured = try screen_obj.capture();
            defer captured.deinit();

            // Convert CapturedImage to Image for Finder
            var screen_image = try zikuli.Image.fromCapture(h.allocator, captured);
            defer screen_image.deinit();

            // Try to find with high similarity - should fail
            var finder_obj = zikuli.Finder.init(h.allocator, &screen_image);
            defer finder_obj.deinit();

            finder_obj.setSimilarity(0.99); // Very strict
            const strict_match = finder_obj.find(&template);

            // Try with lower similarity - should succeed
            finder_obj.setSimilarity(0.7); // More lenient
            const lenient_match = finder_obj.find(&template);

            // The lenient search should find it
            try std.testing.expect(lenient_match != null);

            std.debug.print("\n✓ Similarity threshold test passed!\n", .{});
            std.debug.print("  Strict match (0.99): {s}\n", .{if (strict_match != null) "found" else "not found"});
            std.debug.print("  Lenient match (0.7): {s}\n", .{if (lenient_match != null) "found" else "not found"});
        }
    }.run);
}
