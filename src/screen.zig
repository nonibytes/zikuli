//! Screen abstraction for Zikuli
//!
//! Provides a high-level interface for screen capture and multi-monitor support.
//! This is the user-facing API that wraps platform-specific implementations.
//!
//! Based on SikuliX Screen.java and ScreenDevice.java analysis:
//! - Primary screen contains point (0,0)
//! - Multi-monitor support via screen enumeration
//! - Each monitor has its own bounds
//! - Region-based screen capture

const std = @import("std");
const builtin = @import("builtin");
const geometry = @import("geometry.zig");
const region_mod = @import("region.zig");
const monitors_mod = @import("monitors.zig");
const x11 = @import("platform/x11.zig");

const Rectangle = geometry.Rectangle;
const Point = geometry.Point;
const Region = region_mod.Region;
const Monitors = monitors_mod.Monitors;
const MonitorInfo = monitors_mod.MonitorInfo;
const X11Connection = x11.X11Connection;
const CapturedImage = x11.CapturedImage;

/// A Screen represents a physical display monitor
pub const Screen = struct {
    /// Screen identifier (0 = primary)
    id: i32,

    /// Screen bounds (position and size) for THIS monitor
    bounds: Rectangle,

    /// X11 connection (managed internally)
    connection: ?X11Connection,

    /// Allocator for screen captures
    allocator: std.mem.Allocator,

    /// Monitor name (e.g., "HDMI-1")
    name: [64]u8 = undefined,
    name_len: usize = 0,

    /// Get the primary screen (monitor 0)
    pub fn primary(allocator: std.mem.Allocator) !Screen {
        return get(allocator, 0);
    }

    /// Get a specific screen by ID
    /// ID 0 = primary monitor
    /// ID 1 = second monitor, etc.
    /// This matches SikuliX behavior: Screen(0) returns primary, Screen(1) returns second
    pub fn get(allocator: std.mem.Allocator, screen_id: i32) !Screen {
        var conn = try X11Connection.connectDefault();
        errdefer conn.disconnect();

        // Use XRandR to get individual monitor bounds (like SikuliX does)
        var monitors = try Monitors.init(allocator);
        defer monitors.deinit();

        const monitor_info = monitors.get(@intCast(screen_id)) catch |err| {
            // If monitor enumeration fails, fall back to full screen
            if (err == error.InvalidMonitorIndex) {
                return err;
            }
            // Fallback: use combined virtual screen (old behavior)
            const bounds = conn.getScreenBounds();
            return Screen{
                .id = screen_id,
                .bounds = bounds,
                .connection = conn,
                .allocator = allocator,
            };
        };

        var screen = Screen{
            .id = screen_id,
            .bounds = monitor_info.bounds,
            .connection = conn,
            .allocator = allocator,
        };

        // Copy monitor name
        @memcpy(screen.name[0..monitor_info.name_len], monitor_info.name[0..monitor_info.name_len]);
        screen.name_len = monitor_info.name_len;

        return screen;
    }

    /// Get virtual screen containing all monitors
    /// This returns the combined bounds of all displays
    pub fn virtual(allocator: std.mem.Allocator) !Screen {
        var conn = try X11Connection.connectDefault();
        errdefer conn.disconnect();

        // Get combined virtual screen bounds
        var monitors = try Monitors.init(allocator);
        defer monitors.deinit();

        const virtual_bounds = monitors.getVirtualScreen() catch conn.getScreenBounds();

        return Screen{
            .id = -1, // -1 indicates virtual screen
            .bounds = virtual_bounds,
            .connection = conn,
            .allocator = allocator,
        };
    }

    /// Get the number of connected monitors
    pub fn getMonitorCount(allocator: std.mem.Allocator) !u32 {
        var monitors = try Monitors.init(allocator);
        defer monitors.deinit();
        return monitors.getCount();
    }

    /// Get the monitor name (e.g., "HDMI-1", "eDP-1")
    pub fn getName(self: Screen) []const u8 {
        return self.name[0..self.name_len];
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

    /// Capture this screen (monitor)
    /// For individual monitors, captures just that monitor's region
    /// For virtual screen (id=-1), captures all monitors combined
    pub fn capture(self: *Screen) !CapturedImage {
        if (self.connection) |*conn| {
            // Capture just this monitor's region, not the full virtual screen
            return conn.captureRegion(self.allocator, self.bounds);
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
