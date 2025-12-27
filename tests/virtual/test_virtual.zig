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
