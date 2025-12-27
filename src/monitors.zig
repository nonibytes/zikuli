//! Cross-platform Multi-Monitor Support
//!
//! Provides enumeration of physical display monitors.
//! Implements the same pattern as SikuliX's ScreenDevice.java:
//! - Primary monitor contains point (0,0)
//! - Each monitor has its own bounds (x, y, width, height)
//! - Monitor ID 0 = primary, 1 = second monitor, etc.
//!
//! Platform implementations:
//! - Linux: XRandR extension
//! - macOS: Core Graphics (TODO)
//! - Windows: EnumDisplayMonitors (TODO)

const std = @import("std");
const builtin = @import("builtin");
const geometry = @import("geometry.zig");
const Rectangle = geometry.Rectangle;
const Point = geometry.Point;

// Platform-specific implementation
const xrandr = if (builtin.os.tag == .linux) @import("platform/xrandr.zig") else struct {};

/// Information about a single physical monitor
/// On Linux, this is xrandr.MonitorInfo; on other platforms it's our own struct
pub const MonitorInfo = if (builtin.os.tag == .linux) xrandr.MonitorInfo else struct {
    /// Monitor index (0 = primary)
    id: u32,
    /// Monitor bounds (x, y, width, height) in virtual screen coordinates
    bounds: Rectangle,
    /// Whether this is the primary monitor
    is_primary: bool,
    /// Monitor name (e.g., "HDMI-1", "eDP-1")
    name: [64]u8,
    name_len: usize,

    pub fn getName(self: @This()) []const u8 {
        return self.name[0..self.name_len];
    }

    /// Check if this monitor contains a point
    pub fn contains(self: @This(), point: Point) bool {
        return self.bounds.contains(point);
    }

    /// Get the center of this monitor
    pub fn center(self: @This()) Point {
        return self.bounds.center();
    }
};

/// Multi-monitor manager for enumerating and querying displays
pub const Monitors = struct {
    allocator: std.mem.Allocator,

    // Platform-specific connection
    connection: if (builtin.os.tag == .linux) xrandr.XRandRConnection else void,

    /// Connect and initialize the monitor system
    pub fn init(allocator: std.mem.Allocator) !Monitors {
        if (builtin.os.tag == .linux) {
            const conn = try xrandr.XRandRConnection.connect(allocator);
            return Monitors{
                .allocator = allocator,
                .connection = conn,
            };
        } else if (builtin.os.tag == .macos) {
            // TODO: macOS Core Graphics implementation
            @compileError("macOS multi-monitor not yet implemented");
        } else if (builtin.os.tag == .windows) {
            // TODO: Windows EnumDisplayMonitors implementation
            @compileError("Windows multi-monitor not yet implemented");
        } else {
            @compileError("Unsupported platform for multi-monitor");
        }
    }

    /// Disconnect and clean up
    pub fn deinit(self: *Monitors) void {
        if (builtin.os.tag == .linux) {
            self.connection.disconnect();
        }
    }

    /// Get the number of connected monitors
    pub fn getCount(self: *Monitors) !u32 {
        if (builtin.os.tag == .linux) {
            return self.connection.getMonitorCount();
        }
        return 1;
    }

    /// Get all connected monitors
    /// Caller must free the returned slice with self.allocator
    pub fn getAll(self: *Monitors) ![]MonitorInfo {
        if (builtin.os.tag == .linux) {
            // MonitorInfo is the same type as xrandr.MonitorInfo on Linux
            return self.connection.getMonitors();
        }

        // Fallback: single monitor with full screen bounds
        var result = try self.allocator.alloc(MonitorInfo, 1);
        result[0] = MonitorInfo{
            .id = 0,
            .bounds = Rectangle.init(0, 0, 1920, 1080),
            .is_primary = true,
            .name = undefined,
            .name_len = 0,
        };
        return result;
    }

    /// Get a specific monitor by ID
    /// ID 0 = primary monitor
    pub fn get(self: *Monitors, monitor_id: u32) !MonitorInfo {
        if (builtin.os.tag == .linux) {
            return self.connection.getMonitor(monitor_id);
        }

        // Fallback
        if (monitor_id != 0) {
            return error.InvalidMonitorIndex;
        }
        return MonitorInfo{
            .id = 0,
            .bounds = Rectangle.init(0, 0, 1920, 1080),
            .is_primary = true,
            .name = undefined,
            .name_len = 0,
        };
    }

    /// Get the primary monitor (ID 0)
    pub fn getPrimary(self: *Monitors) !MonitorInfo {
        return self.get(0);
    }

    /// Find which monitor contains a given point
    pub fn getForPoint(self: *Monitors, point: Point) !?MonitorInfo {
        if (builtin.os.tag == .linux) {
            return self.connection.getMonitorForPoint(point);
        }

        const primary = try self.getPrimary();
        if (primary.bounds.contains(point)) {
            return primary;
        }
        return null;
    }

    /// Get the combined virtual screen bounds (all monitors)
    pub fn getVirtualScreen(self: *Monitors) !Rectangle {
        if (builtin.os.tag == .linux) {
            return self.connection.getVirtualScreenBounds();
        }

        return Rectangle.init(0, 0, 1920, 1080);
    }

    /// Free a slice of MonitorInfo returned by getAll()
    pub fn freeMonitors(self: *Monitors, monitors: []MonitorInfo) void {
        self.allocator.free(monitors);
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Monitors: compile check" {
    _ = MonitorInfo;
    _ = Monitors;
}
