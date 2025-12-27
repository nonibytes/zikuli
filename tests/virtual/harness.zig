//! Virtual Test Harness
//!
//! Orchestrates the complete test flow:
//! 1. Start virtual display (Xvfb)
//! 2. Place test content at known locations
//! 3. Run Zikuli operations
//! 4. Verify results
//! 5. Clean up
//!
//! Usage:
//!   var harness = try TestHarness.init(allocator);
//!   defer harness.deinit();
//!
//!   // Place content
//!   var win = try harness.placeColorSquare(100, 200, 50, .{ .r = 255, .g = 0, .b = 0 });
//!
//!   // Run Zikuli operations
//!   const result = try zikuli.finder.find(...);
//!
//!   // Verify
//!   try harness.verifier.expectMouseAt(125, 225, 5);

const std = @import("std");
const zikuli = @import("zikuli");
const content_server = @import("content_server.zig");
const verification = @import("verification.zig");

pub const ContentServer = content_server.ContentServer;
pub const Window = content_server.Window;
pub const Verifier = verification.Verifier;

/// Test harness for virtual display testing
pub const TestHarness = struct {
    allocator: std.mem.Allocator,
    content: ContentServer,
    verifier: Verifier,
    placed_windows: std.ArrayList(PlacedWindow),

    pub const PlacedWindow = struct {
        window: *Window,
        description: []const u8,
        expected_x: i16,
        expected_y: i16,
        expected_color: ?struct { r: u8, g: u8, b: u8 },
    };

    pub fn init(allocator: std.mem.Allocator) !TestHarness {
        const content = try ContentServer.init(allocator);
        errdefer content.deinit();

        const verifier = try Verifier.init(allocator);
        errdefer verifier.deinit();

        return TestHarness{
            .allocator = allocator,
            .content = content,
            .verifier = verifier,
            .placed_windows = std.ArrayList(PlacedWindow).init(allocator),
        };
    }

    pub fn deinit(self: *TestHarness) void {
        // Free descriptions
        for (self.placed_windows.items) |pw| {
            self.allocator.free(pw.description);
        }
        self.placed_windows.deinit();

        self.content.deinit();
        self.verifier.deinit();
    }

    /// Place a solid color square at exact coordinates
    pub fn placeColorSquare(
        self: *TestHarness,
        x: i16,
        y: i16,
        size: u16,
        color: struct { r: u8, g: u8, b: u8 },
    ) !*Window {
        var win = try self.content.createWindow(x, y, size, size);
        win.fillColor(color.r, color.g, color.b);
        win.map();
        self.content.sync();

        const desc = try std.fmt.allocPrint(
            self.allocator,
            "Color square ({}, {}, {}) at ({}, {})",
            .{ color.r, color.g, color.b, x, y },
        );

        try self.placed_windows.append(.{
            .window = win,
            .description = desc,
            .expected_x = x,
            .expected_y = y,
            .expected_color = color,
        });

        return win;
    }

    /// Place multiple test patterns for comprehensive testing
    pub fn setupTestScene(self: *TestHarness) !void {
        // Red square at top-left area
        _ = try self.placeColorSquare(100, 100, 50, .{ .r = 255, .g = 0, .b = 0 });

        // Blue square at center area
        const screen = self.content.getScreenSize();
        const center_x: i16 = @intCast(screen.width / 2 - 25);
        const center_y: i16 = @intCast(screen.height / 2 - 25);
        _ = try self.placeColorSquare(center_x, center_y, 50, .{ .r = 0, .g = 0, .b = 255 });

        // Green square at bottom-right area
        _ = try self.placeColorSquare(
            @intCast(screen.width - 150),
            @intCast(screen.height - 150),
            50,
            .{ .r = 0, .g = 255, .b = 0 },
        );

        self.content.flush();
        self.content.sync();

        // Small delay to ensure rendering is complete
        std.time.sleep(50 * std.time.ns_per_ms);
    }

    /// Verify that a window is visible at its expected location
    pub fn verifyWindowVisible(self: *TestHarness, pw: PlacedWindow) !void {
        if (pw.expected_color) |color| {
            // Check center pixel of the window
            const center_x = pw.expected_x + @as(i16, @intCast(pw.window.width / 2));
            const center_y = pw.expected_y + @as(i16, @intCast(pw.window.height / 2));

            try self.verifier.expectColorAt(center_x, center_y, color.r, color.g, color.b, 5);
        }
    }

    /// Verify all placed windows are visible
    pub fn verifyAllVisible(self: *TestHarness) !void {
        for (self.placed_windows.items) |pw| {
            try self.verifyWindowVisible(pw);
        }
    }

    /// Get screen dimensions
    pub fn getScreenSize(self: *TestHarness) struct { width: u16, height: u16 } {
        return self.content.getScreenSize();
    }

    /// Find a placed window by its approximate location
    pub fn findPlacedWindow(self: *TestHarness, x: i32, y: i32, tolerance: u32) ?PlacedWindow {
        for (self.placed_windows.items) |pw| {
            const dx = @abs(@as(i32, pw.expected_x) - x);
            const dy = @abs(@as(i32, pw.expected_y) - y);
            if (dx <= tolerance and dy <= tolerance) {
                return pw;
            }
        }
        return null;
    }

    /// Print summary of placed content (for debugging)
    pub fn printPlacedContent(self: *TestHarness) void {
        std.debug.print("\n=== Placed Test Content ===\n", .{});
        for (self.placed_windows.items, 0..) |pw, i| {
            std.debug.print("[{}] {s}\n", .{ i, pw.description });
            std.debug.print("    Position: ({}, {}), Size: {}x{}\n", .{
                pw.expected_x,
                pw.expected_y,
                pw.window.width,
                pw.window.height,
            });
        }
        std.debug.print("===========================\n\n", .{});
    }
};

/// Convenience function to run a test in the virtual environment
pub fn runVirtualTest(
    allocator: std.mem.Allocator,
    comptime testFn: fn (*TestHarness) anyerror!void,
) !void {
    var harness = TestHarness.init(allocator) catch |err| {
        if (err == error.ConnectionFailed) {
            std.debug.print("Skipping test: No X11 display available\n", .{});
            std.debug.print("Run with: DISPLAY=:99 or use tests/scripts/run_virtual_tests.sh\n", .{});
            return;
        }
        return err;
    };
    defer harness.deinit();

    try testFn(&harness);
}

// ============================================================================
// Tests
// ============================================================================

test "TestHarness: initialization" {
    const allocator = std.testing.allocator;

    try runVirtualTest(allocator, struct {
        fn run(harness: *TestHarness) !void {
            const size = harness.getScreenSize();
            try std.testing.expect(size.width > 0);
            try std.testing.expect(size.height > 0);
        }
    }.run);
}

test "TestHarness: place and verify color square" {
    const allocator = std.testing.allocator;

    try runVirtualTest(allocator, struct {
        fn run(harness: *TestHarness) !void {
            // Place red square
            _ = try harness.placeColorSquare(100, 100, 50, .{ .r = 255, .g = 0, .b = 0 });

            // Wait for rendering
            std.time.sleep(100 * std.time.ns_per_ms);

            // Verify it's visible
            try harness.verifyAllVisible();
        }
    }.run);
}

test "TestHarness: setup test scene" {
    const allocator = std.testing.allocator;

    try runVirtualTest(allocator, struct {
        fn run(harness: *TestHarness) !void {
            try harness.setupTestScene();

            // Should have 3 windows placed
            try std.testing.expectEqual(@as(usize, 3), harness.placed_windows.items.len);

            harness.printPlacedContent();
        }
    }.run);
}
