//! Screen abstraction for Zikuli
//!
//! Provides a high-level interface for screen capture and multi-monitor support.
//! This is the user-facing API that wraps platform-specific implementations.
//!
//! Based on SikuliX Screen.java and ScreenDevice.java analysis:
//! - Primary screen contains point (0,0)
//! - Multi-monitor support via screen enumeration
//! - Region-based screen capture

const std = @import("std");
const geometry = @import("geometry.zig");
const region_mod = @import("region.zig");
const x11 = @import("platform/x11.zig");

const Rectangle = geometry.Rectangle;
const Point = geometry.Point;
const Region = region_mod.Region;
const X11Connection = x11.X11Connection;
const CapturedImage = x11.CapturedImage;

/// A Screen represents a physical display monitor
pub const Screen = struct {
    /// Screen identifier (0 = primary)
    id: i32,

    /// Screen bounds (position and size)
    bounds: Rectangle,

    /// X11 connection (managed internally)
    connection: ?X11Connection,

    /// Allocator for screen captures
    allocator: std.mem.Allocator,

    /// Get the primary screen
    pub fn primary(allocator: std.mem.Allocator) !Screen {
        return get(allocator, 0);
    }

    /// Get a specific screen by ID
    pub fn get(allocator: std.mem.Allocator, screen_id: i32) !Screen {
        var conn = try X11Connection.connectDefault();
        errdefer conn.disconnect();

        const bounds = conn.getScreenBounds();

        return Screen{
            .id = screen_id,
            .bounds = bounds,
            .connection = conn,
            .allocator = allocator,
        };
    }

    /// Close the screen connection
    pub fn deinit(self: *Screen) void {
        if (self.connection) |*conn| {
            conn.disconnect();
            self.connection = null;
        }
    }

    /// Get screen width
    pub fn width(self: Screen) u32 {
        return self.bounds.width;
    }

    /// Get screen height
    pub fn height(self: Screen) u32 {
        return self.bounds.height;
    }

    /// Get the screen as a Region
    pub fn asRegion(self: Screen) Region {
        return Region.init(self.bounds);
    }

    /// Get screen center point
    pub fn center(self: Screen) Point {
        return self.bounds.center();
    }

    /// Check if a point is on this screen
    pub fn contains(self: Screen, p: Point) bool {
        return self.bounds.contains(p);
    }

    /// Capture the entire screen
    pub fn capture(self: *Screen) !CapturedImage {
        if (self.connection) |*conn| {
            return conn.captureFullScreen(self.allocator);
        }
        return error.NotConnected;
    }

    /// Capture a rectangular region of the screen
    pub fn captureRegion(self: *Screen, rect: Rectangle) !CapturedImage {
        if (self.connection) |*conn| {
            return conn.captureRegion(self.allocator, rect);
        }
        return error.NotConnected;
    }

    /// Capture a Region
    pub fn captureArea(self: *Screen, reg: Region) !CapturedImage {
        return self.captureRegion(reg.rect);
    }

    /// Check if screen is connected
    pub fn isConnected(self: Screen) bool {
        return self.connection != null;
    }

    pub fn format(
        self: Screen,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Screen[{d}]({d}x{d})", .{
            self.id,
            self.bounds.width,
            self.bounds.height,
        });
    }
};

/// Error type for screen operations
pub const ScreenError = error{
    NotConnected,
    CaptureError,
};

// ============================================================================
// TESTS
// ============================================================================

test "Screen: compile check" {
    // Verify the module compiles
    _ = Screen;
    _ = ScreenError;
}
