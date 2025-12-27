//! Virtual Environment Tests for Zikuli
//!
//! These tests run in a virtual X11 environment (Xvfb) with
//! test content placed at known locations.
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
            // Place some content
            _ = try h.placeColorSquare(100, 100, 50, RGB{ .r = 255, .g = 0, .b = 0 });

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Capture full screen
            var screen = try zikuli.Screen.virtual(h.allocator);
            defer screen.deinit();

            var captured = try screen.capture();
            defer captured.deinit();

            // Verify dimensions match screen
            const screen_size = h.getScreenSize();
            try std.testing.expectEqual(screen_size.width, @as(u16, @intCast(captured.width)));
            try std.testing.expectEqual(screen_size.height, @as(u16, @intCast(captured.height)));
        }
    }.run);
}

test "capture: region dimensions" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place red square at (200, 200)
            _ = try h.placeColorSquare(200, 200, 50, RGB{ .r = 255, .g = 0, .b = 0 });

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Capture just that region
            var screen = try zikuli.Screen.virtual(h.allocator);
            defer screen.deinit();

            var captured = try screen.captureRegion(zikuli.Rectangle.init(200, 200, 50, 50));
            defer captured.deinit();

            // Verify dimensions
            try std.testing.expectEqual(@as(u32, 50), captured.width);
            try std.testing.expectEqual(@as(u32, 50), captured.height);
        }
    }.run);
}

// ============================================================================
// Mouse Tests
// ============================================================================

test "mouse: move to position" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Move to known position
            try zikuli.Mouse.moveTo(500, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Verify position
            const pos1 = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos1.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos1.y)), 5);

            // Move to another position
            try zikuli.Mouse.moveTo(100, 100);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos2 = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 100), @as(f64, @floatFromInt(pos2.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 100), @as(f64, @floatFromInt(pos2.y)), 5);
        }
    }.run);
}

test "mouse: click at position" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Click at position
            try zikuli.Mouse.clickAt(300, 200, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Verify mouse ended at click position
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 200), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

// ============================================================================
// Content Placement Tests
// ============================================================================

test "content: place and verify color square" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place red square
            _ = try h.placeColorSquare(300, 300, 50, RGB{ .r = 255, .g = 0, .b = 0 });

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify it's visible using the verifier
            try h.verifier.expectColorAt(325, 325, 255, 0, 0, 50);
        }
    }.run);
}

test "content: setup test scene with multiple squares" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            try h.setupTestScene();

            // Should have 3 windows placed
            try std.testing.expectEqual(@as(usize, 3), h.placed_windows.items.len);

            h.printPlacedContent();
        }
    }.run);
}

// ============================================================================
// Edge Case Tests
// ============================================================================

test "edge: screen corners" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const screen_size = h.getScreenSize();

            // Place content near corners (avoid edge clipping)
            _ = try h.placeColorSquare(5, 5, 30, RGB{ .r = 255, .g = 0, .b = 0 }); // Top-left

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify top-left corner has content
            try h.verifier.expectColorAt(20, 20, 255, 0, 0, 50);

            // Verify screen dimensions are sensible
            try std.testing.expect(screen_size.width > 0);
            try std.testing.expect(screen_size.height > 0);
        }
    }.run);
}

test "edge: small pattern" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place minimum size pattern (15x15)
            _ = try h.placeColorSquare(500, 500, 15, RGB{ .r = 255, .g = 255, .b = 0 });
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify it exists at center
            try h.verifier.expectColorAt(507, 507, 255, 255, 0, 50);
        }
    }.run);
}

// ============================================================================
// Drag and Drop Tests
// ============================================================================

test "drag: basic drag operation" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Start at position
            try zikuli.Mouse.moveTo(100, 100);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Drag to new position
            try zikuli.Mouse.drag(400, 300, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify mouse ended at drag destination
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "drag: dragFromTo operation" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Perform drag from one position to another
            try zikuli.Mouse.dragFromTo(200, 200, 600, 400, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify mouse ended at drag destination
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 600), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "drag: drag with right button" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Drag with right mouse button (context drag)
            try zikuli.Mouse.dragFromTo(150, 150, 350, 250, .right);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify destination
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 350), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 250), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "drag: drag with middle button" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Drag with middle mouse button
            try zikuli.Mouse.dragFromTo(250, 250, 450, 350, .middle);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 450), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 350), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "drag: short distance drag" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Very short drag (10 pixels)
            try zikuli.Mouse.dragFromTo(500, 500, 510, 510, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 510), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 510), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "drag: long distance drag" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const screen_size = h.getScreenSize();
            // Drag across most of the screen
            try zikuli.Mouse.dragFromTo(50, 50, @intCast(screen_size.width - 50), @intCast(screen_size.height - 50), .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, @floatFromInt(screen_size.width - 50)), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, @floatFromInt(screen_size.height - 50)), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

// ============================================================================
// Scroll Tests
// ============================================================================

test "scroll: wheel up" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Move to a position and scroll up
            try zikuli.Mouse.moveTo(500, 400);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll up 5 steps
            try zikuli.Mouse.wheelUp(5);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Position should remain the same after scroll
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "scroll: wheel down" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Move to a position and scroll down
            try zikuli.Mouse.moveTo(600, 350);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll down 5 steps
            try zikuli.Mouse.wheelDown(5);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Position should remain the same
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 600), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 350), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "scroll: multiple scroll sequences" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(400, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll down, then up, then down again
            try zikuli.Mouse.wheelDown(3);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            try zikuli.Mouse.wheelUp(2);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            try zikuli.Mouse.wheelDown(4);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Position unchanged
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "scroll: single step scroll" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(300, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Single step scrolls
            try zikuli.Mouse.wheelUp(1);
            std.Thread.sleep(30 * std.time.ns_per_ms);
            try zikuli.Mouse.wheelDown(1);
            std.Thread.sleep(30 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.x)), 5);
        }
    }.run);
}

// ============================================================================
// Double Click Tests
// ============================================================================

test "click: double left click" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Move and double click
            try zikuli.Mouse.moveTo(450, 350);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            try zikuli.Mouse.doubleLeftClick();
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Position should remain
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 450), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 350), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "click: double click with button param" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(550, 250);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            try zikuli.Mouse.doubleClick(.left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 550), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 250), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

// ============================================================================
// Right Click Tests
// ============================================================================

test "click: right click" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(350, 400);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            try zikuli.Mouse.rightClick();
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 350), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "click: middle click" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(650, 450);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            try zikuli.Mouse.middleClick();
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 650), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 450), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

// ============================================================================
// Smooth Movement Tests
// ============================================================================

test "mouse: smooth move short distance" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Start position
            try zikuli.Mouse.moveTo(200, 200);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Smooth move (short distance, faster duration)
            try zikuli.Mouse.smoothMove(250, 250, 100);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 250), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 250), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "mouse: smooth move long distance" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(100, 100);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Smooth move across screen
            try zikuli.Mouse.smoothMove(800, 600, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 800), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 600), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "mouse: smoothMoveTo with default duration" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(300, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Use default duration smoothMoveTo
            try zikuli.Mouse.smoothMoveTo(450, 450);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 450), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 450), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

// ============================================================================
// Button State Tests
// ============================================================================

test "mouse: button down and up" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(400, 400);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Press button down
            try zikuli.Mouse.buttonDown(.left);
            std.Thread.sleep(20 * std.time.ns_per_ms);

            // Verify button is held
            const state1 = zikuli.Mouse.getState();
            try std.testing.expect(state1.isButtonHeld(.left));

            // Release button
            try zikuli.Mouse.buttonUp(.left);
            std.Thread.sleep(20 * std.time.ns_per_ms);

            // Verify button released
            const state2 = zikuli.Mouse.getState();
            try std.testing.expect(!state2.isButtonHeld(.left));
        }
    }.run);
}

test "mouse: reset releases all buttons" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(300, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Press multiple buttons
            try zikuli.Mouse.buttonDown(.left);
            try zikuli.Mouse.buttonDown(.right);
            std.Thread.sleep(20 * std.time.ns_per_ms);

            // Reset should release all
            try zikuli.Mouse.reset();
            std.Thread.sleep(20 * std.time.ns_per_ms);

            const state = zikuli.Mouse.getState();
            try std.testing.expect(!state.isButtonHeld(.left));
            try std.testing.expect(!state.isButtonHeld(.right));
        }
    }.run);
}

// ============================================================================
// Multiple Content Tests
// ============================================================================

test "content: multiple color squares" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place multiple colored squares
            _ = try h.placeColorSquare(100, 100, 40, RGB{ .r = 255, .g = 0, .b = 0 }); // Red
            _ = try h.placeColorSquare(200, 100, 40, RGB{ .r = 0, .g = 255, .b = 0 }); // Green
            _ = try h.placeColorSquare(300, 100, 40, RGB{ .r = 0, .g = 0, .b = 255 }); // Blue
            _ = try h.placeColorSquare(400, 100, 40, RGB{ .r = 255, .g = 255, .b = 0 }); // Yellow

            std.Thread.sleep(150 * std.time.ns_per_ms);

            // Verify 4 windows placed
            try std.testing.expectEqual(@as(usize, 4), h.placed_windows.items.len);
        }
    }.run);
}

test "content: overlapping squares" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Place overlapping squares (second should be on top)
            _ = try h.placeColorSquare(400, 400, 100, RGB{ .r = 255, .g = 0, .b = 0 }); // Red base
            _ = try h.placeColorSquare(420, 420, 60, RGB{ .r = 0, .g = 255, .b = 0 }); // Green on top

            std.Thread.sleep(150 * std.time.ns_per_ms);

            // The center of the overlap should show green (top layer)
            try h.verifier.expectColorAt(450, 450, 0, 255, 0, 50);
        }
    }.run);
}

// ============================================================================
// Realistic Automation Scenarios
// ============================================================================

test "scenario: click through color targets" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Place 3 target squares in a row
            _ = try h.placeColorSquare(100, 300, 50, RGB{ .r = 255, .g = 0, .b = 0 }); // Target 1
            _ = try h.placeColorSquare(300, 300, 50, RGB{ .r = 0, .g = 255, .b = 0 }); // Target 2
            _ = try h.placeColorSquare(500, 300, 50, RGB{ .r = 0, .g = 0, .b = 255 }); // Target 3

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Automation: Click the center of each target in sequence
            // Target 1 center: (125, 325)
            try zikuli.Mouse.clickAt(125, 325, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);
            var pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 125), @as(f64, @floatFromInt(pos.x)), 10);

            // Target 2 center: (325, 325)
            try zikuli.Mouse.clickAt(325, 325, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 325), @as(f64, @floatFromInt(pos.x)), 10);

            // Target 3 center: (525, 325)
            try zikuli.Mouse.clickAt(525, 325, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 525), @as(f64, @floatFromInt(pos.x)), 10);
        }
    }.run);
}

test "scenario: drag item between containers" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Simulate drag-and-drop: drag an item from source to target container
            // Place "source container" (where item starts)
            _ = try h.placeColorSquare(100, 200, 100, RGB{ .r = 200, .g = 200, .b = 200 }); // Gray source

            // Place "target container" (where item should be dropped)
            _ = try h.placeColorSquare(400, 200, 100, RGB{ .r = 150, .g = 200, .b = 255 }); // Blue target

            // Place "draggable item" inside source
            _ = try h.placeColorSquare(125, 225, 50, RGB{ .r = 255, .g = 100, .b = 100 }); // Red item

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Perform drag from item center to target container center
            // Item center: (150, 250), Target center: (450, 250)
            try zikuli.Mouse.dragFromTo(150, 250, 450, 250, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify mouse ended at drop location
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 450), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 250), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "scenario: scroll and click workflow" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Simulate scrolling through a list and clicking an item

            // Move to "scroll area"
            try zikuli.Mouse.moveTo(600, 400);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll down to find item
            try zikuli.Mouse.wheelDown(5);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Click the item that came into view
            try zikuli.Mouse.click(.left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll back up
            try zikuli.Mouse.wheelUp(5);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify position unchanged
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 600), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "scenario: double-click to open then right-click menu" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Simulate: double-click to "open" something, then right-click for context menu
            _ = try h.placeColorSquare(300, 300, 80, RGB{ .r = 100, .g = 150, .b = 200 }); // File icon

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Move to icon center (340, 340)
            try zikuli.Mouse.moveTo(340, 340);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Double-click to "open"
            try zikuli.Mouse.doubleLeftClick();
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Right-click for context menu
            try zikuli.Mouse.rightClick();
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 340), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 340), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "scenario: multi-select with shift-drag" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Place multiple items to "select"
            _ = try h.placeColorSquare(200, 200, 40, RGB{ .r = 255, .g = 200, .b = 200 }); // Item 1
            _ = try h.placeColorSquare(260, 200, 40, RGB{ .r = 200, .g = 255, .b = 200 }); // Item 2
            _ = try h.placeColorSquare(320, 200, 40, RGB{ .r = 200, .g = 200, .b = 255 }); // Item 3
            _ = try h.placeColorSquare(380, 200, 40, RGB{ .r = 255, .g = 255, .b = 200 }); // Item 4

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Simulate selection box drag (from before first item to after last)
            // Start point: (180, 180), End point: (440, 260)
            try zikuli.Mouse.dragFromTo(180, 180, 440, 260, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Verify drag completed at end position
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 440), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 260), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "scenario: toolbar button clicks" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Create a row of toolbar buttons
            const button_size: u16 = 40;
            const toolbar_y: i16 = 50;
            const spacing: i16 = 50;

            _ = try h.placeColorSquare(100, toolbar_y, button_size, RGB{ .r = 255, .g = 0, .b = 0 }); // Save
            _ = try h.placeColorSquare(100 + spacing, toolbar_y, button_size, RGB{ .r = 0, .g = 255, .b = 0 }); // Copy
            _ = try h.placeColorSquare(100 + spacing * 2, toolbar_y, button_size, RGB{ .r = 0, .g = 0, .b = 255 }); // Paste
            _ = try h.placeColorSquare(100 + spacing * 3, toolbar_y, button_size, RGB{ .r = 255, .g = 255, .b = 0 }); // Undo

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Click each toolbar button in sequence
            const button_center_y = toolbar_y + @as(i16, @intCast(button_size / 2));
            const button_center_offset = @as(i16, @intCast(button_size / 2));

            // Click Save button
            try zikuli.Mouse.clickAt(100 + button_center_offset, button_center_y, .left);
            std.Thread.sleep(80 * std.time.ns_per_ms);

            // Click Copy button
            try zikuli.Mouse.clickAt(100 + spacing + button_center_offset, button_center_y, .left);
            std.Thread.sleep(80 * std.time.ns_per_ms);

            // Click Paste button
            try zikuli.Mouse.clickAt(100 + spacing * 2 + button_center_offset, button_center_y, .left);
            std.Thread.sleep(80 * std.time.ns_per_ms);

            // Click Undo button
            try zikuli.Mouse.clickAt(100 + spacing * 3 + button_center_offset, button_center_y, .left);
            std.Thread.sleep(80 * std.time.ns_per_ms);

            // Verify ended at last button
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 100 + spacing * 3 + button_center_offset), @as(f64, @floatFromInt(pos.x)), 10);
        }
    }.run);
}

test "scenario: form field navigation" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Create form fields (simulated as colored rectangles)
            const field_width: u16 = 150;
            const field_height: u16 = 30;

            // Username field
            _ = try h.placeColorSquare(200, 100, field_width, RGB{ .r = 240, .g = 240, .b = 240 });
            // Password field
            _ = try h.placeColorSquare(200, 150, field_width, RGB{ .r = 240, .g = 240, .b = 240 });
            // Submit button
            _ = try h.placeColorSquare(200, 210, 80, RGB{ .r = 100, .g = 180, .b = 100 });

            // Use field_height to avoid unused variable warning
            _ = field_height;

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Click username field
            try zikuli.Mouse.clickAt(275, 115, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Click password field
            try zikuli.Mouse.clickAt(275, 165, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Click submit button
            try zikuli.Mouse.clickAt(240, 225, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 240), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 225), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "scenario: resize handle drag" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Window with resize handle in corner
            _ = try h.placeColorSquare(200, 200, 200, RGB{ .r = 220, .g = 220, .b = 220 }); // Window
            _ = try h.placeColorSquare(385, 385, 15, RGB{ .r = 100, .g = 100, .b = 100 }); // Resize handle

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Drag resize handle to make window bigger
            // From (392, 392) to (500, 500) - expanding by 108 pixels
            try zikuli.Mouse.dragFromTo(392, 392, 500, 500, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "scenario: list item reordering" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Vertical list of items
            const item_height: i16 = 35;
            const list_x: i16 = 300;
            const list_start_y: i16 = 100;

            _ = try h.placeColorSquare(list_x, list_start_y, 120, RGB{ .r = 255, .g = 200, .b = 200 }); // Item A
            _ = try h.placeColorSquare(list_x, list_start_y + item_height, 120, RGB{ .r = 200, .g = 255, .b = 200 }); // Item B
            _ = try h.placeColorSquare(list_x, list_start_y + item_height * 2, 120, RGB{ .r = 200, .g = 200, .b = 255 }); // Item C
            _ = try h.placeColorSquare(list_x, list_start_y + item_height * 3, 120, RGB{ .r = 255, .g = 255, .b = 200 }); // Item D

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Drag Item A (top) to below Item C (reorder)
            const item_center_x = list_x + 60;
            const item_a_center_y = list_start_y + 17; // Center of Item A
            const target_y = list_start_y + item_height * 2 + 17; // Between C and D

            try zikuli.Mouse.dragFromTo(item_center_x, item_a_center_y, item_center_x, target_y, .left);
            std.Thread.sleep(100 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, item_center_x), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, target_y), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "scenario: canvas drawing simulation" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            // Setup: Drawing canvas
            _ = try h.placeColorSquare(100, 100, 400, RGB{ .r = 255, .g = 255, .b = 255 }); // White canvas

            std.Thread.sleep(100 * std.time.ns_per_ms);

            // Draw a simple path: move to start, drag in a pattern
            // This simulates freehand drawing

            // Start point
            try zikuli.Mouse.moveTo(150, 150);
            std.Thread.sleep(30 * std.time.ns_per_ms);

            // Draw horizontal line
            try zikuli.Mouse.drag(350, 150, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Draw diagonal line
            try zikuli.Mouse.drag(350, 350, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Draw back to start
            try zikuli.Mouse.drag(150, 150, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Final position should be back at start
            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 150), @as(f64, @floatFromInt(pos.x)), 10);
            try std.testing.expectApproxEqAbs(@as(f64, 150), @as(f64, @floatFromInt(pos.y)), 10);
        }
    }.run);
}

test "scenario: scroll paginated content" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Simulate scrolling through paginated content (like a document)

            // Move to document area
            try zikuli.Mouse.moveTo(500, 400);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll down one "page" (many steps)
            try zikuli.Mouse.wheelDown(10);
            std.Thread.sleep(150 * std.time.ns_per_ms);

            // Click something on this "page"
            try zikuli.Mouse.click(.left);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Scroll down more
            try zikuli.Mouse.wheelDown(10);
            std.Thread.sleep(150 * std.time.ns_per_ms);

            // Scroll back to top
            try zikuli.Mouse.wheelUp(20);
            std.Thread.sleep(200 * std.time.ns_per_ms);

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

// ============================================================================
// Edge Cases and Stress Tests
// ============================================================================

test "stress: rapid mouse movements" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            // Rapidly move mouse to many positions
            const positions = [_][2]i32{
                .{ 100, 100 }, .{ 200, 200 }, .{ 300, 100 }, .{ 400, 200 },
                .{ 500, 100 }, .{ 600, 200 }, .{ 700, 100 }, .{ 800, 200 },
                .{ 700, 300 }, .{ 600, 400 }, .{ 500, 300 }, .{ 400, 400 },
                .{ 300, 300 }, .{ 200, 400 }, .{ 100, 300 }, .{ 200, 200 },
            };

            for (positions) |pos| {
                try zikuli.Mouse.moveTo(pos[0], pos[1]);
                std.Thread.sleep(10 * std.time.ns_per_ms);
            }

            // Verify ended at last position
            const final_pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 200), @as(f64, @floatFromInt(final_pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 200), @as(f64, @floatFromInt(final_pos.y)), 5);
        }
    }.run);
}

test "stress: rapid clicks" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(400, 300);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Perform many rapid clicks
            var i: u32 = 0;
            while (i < 20) : (i += 1) {
                try zikuli.Mouse.click(.left);
                std.Thread.sleep(10 * std.time.ns_per_ms);
            }

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}

test "stress: alternating scroll directions" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(500, 400);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Alternate scroll directions rapidly
            var i: u32 = 0;
            while (i < 10) : (i += 1) {
                try zikuli.Mouse.wheelUp(1);
                std.Thread.sleep(20 * std.time.ns_per_ms);
                try zikuli.Mouse.wheelDown(1);
                std.Thread.sleep(20 * std.time.ns_per_ms);
            }

            const pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 500), @as(f64, @floatFromInt(pos.x)), 5);
        }
    }.run);
}

test "edge: boundary clicks" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            const screen_size = h.getScreenSize();

            // Click near screen edges
            // Top-left corner (with small offset to stay in bounds)
            try zikuli.Mouse.clickAt(5, 5, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            var pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.x < 20);
            try std.testing.expect(pos.y < 20);

            // Top-right corner
            try zikuli.Mouse.clickAt(@intCast(screen_size.width - 5), 5, .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.x > screen_size.width - 20);

            // Bottom-left corner
            try zikuli.Mouse.clickAt(5, @intCast(screen_size.height - 5), .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.y > screen_size.height - 20);

            // Bottom-right corner
            try zikuli.Mouse.clickAt(@intCast(screen_size.width - 5), @intCast(screen_size.height - 5), .left);
            std.Thread.sleep(50 * std.time.ns_per_ms);
            pos = try zikuli.Mouse.getPosition();
            try std.testing.expect(pos.x > screen_size.width - 20);
            try std.testing.expect(pos.y > screen_size.height - 20);
        }
    }.run);
}

test "edge: zero and minimum duration smooth move" {
    try harness.runVirtualTest(std.testing.allocator, struct {
        fn run(h: *TestHarness) !void {
            _ = h;
            try zikuli.Mouse.moveTo(200, 200);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            // Zero duration (should be instant)
            try zikuli.Mouse.smoothMove(300, 300, 0);
            std.Thread.sleep(30 * std.time.ns_per_ms);

            var pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 300), @as(f64, @floatFromInt(pos.y)), 5);

            // Very short duration
            try zikuli.Mouse.smoothMove(400, 400, 10);
            std.Thread.sleep(50 * std.time.ns_per_ms);

            pos = try zikuli.Mouse.getPosition();
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.x)), 5);
            try std.testing.expectApproxEqAbs(@as(f64, 400), @as(f64, @floatFromInt(pos.y)), 5);
        }
    }.run);
}
