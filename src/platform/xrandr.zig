//! XRandR Multi-Monitor Support
//!
//! Provides enumeration of individual monitors using XRandR extension.
//! This is how SikuliX handles multi-monitor on Linux.

const std = @import("std");
const geometry = @import("../geometry.zig");
const Rectangle = geometry.Rectangle;
const Point = geometry.Point;

// XRandR C bindings
const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/Xrandr.h");
});

/// Information about a single monitor
pub const MonitorInfo = struct {
    /// Monitor index (0 = primary)
    id: u32,
    /// Monitor bounds (x, y, width, height)
    bounds: Rectangle,
    /// Whether this is the primary monitor
    is_primary: bool,
    /// Monitor name (e.g., "HDMI-1")
    name: [64]u8,
    name_len: usize,

    pub fn getName(self: MonitorInfo) []const u8 {
        return self.name[0..self.name_len];
    }
};

/// XRandR connection for monitor enumeration
pub const XRandRConnection = struct {
    display: *c.Display,
    root: c.Window,
    allocator: std.mem.Allocator,

    /// Connect to X display and initialize XRandR
    pub fn connect(allocator: std.mem.Allocator) !XRandRConnection {
        const display = c.XOpenDisplay(null) orelse {
            return error.CannotOpenDisplay;
        };

        const screen = c.XDefaultScreen(display);
        const root = c.XRootWindow(display, screen);

        return XRandRConnection{
            .display = display,
            .root = root,
            .allocator = allocator,
        };
    }

    /// Disconnect from X display
    pub fn disconnect(self: *XRandRConnection) void {
        _ = c.XCloseDisplay(self.display);
    }

    /// Get the number of monitors
    pub fn getMonitorCount(self: XRandRConnection) !u32 {
        var nmonitors: c_int = 0;
        const monitors = c.XRRGetMonitors(self.display, self.root, 1, &nmonitors);
        if (monitors == null) {
            return error.XRandRFailed;
        }
        defer c.XRRFreeMonitors(monitors);
        return @intCast(nmonitors);
    }

    /// Enumerate all monitors
    pub fn getMonitors(self: XRandRConnection) ![]MonitorInfo {
        var nmonitors: c_int = 0;
        const monitors = c.XRRGetMonitors(self.display, self.root, 1, &nmonitors);
        if (monitors == null) {
            return error.XRandRFailed;
        }
        defer c.XRRFreeMonitors(monitors);

        if (nmonitors <= 0) {
            return error.NoMonitors;
        }

        var result = try self.allocator.alloc(MonitorInfo, @intCast(nmonitors));
        errdefer self.allocator.free(result);

        var primary_idx: u32 = 0;
        for (0..@intCast(nmonitors)) |i| {
            const mon = monitors[i];

            // Get monitor name
            var name_buf: [64]u8 = undefined;
            var name_len: usize = 0;
            if (mon.name != 0) {
                const atom_name = c.XGetAtomName(self.display, mon.name);
                if (atom_name != null) {
                    const slice = std.mem.sliceTo(atom_name, 0);
                    name_len = @min(slice.len, 63);
                    @memcpy(name_buf[0..name_len], slice[0..name_len]);
                    _ = c.XFree(atom_name);
                }
            }

            const is_primary = mon.primary != 0;
            if (is_primary) {
                primary_idx = @intCast(i);
            }

            result[i] = MonitorInfo{
                .id = @intCast(i),
                .bounds = Rectangle.init(
                    mon.x,
                    mon.y,
                    @intCast(mon.width),
                    @intCast(mon.height),
                ),
                .is_primary = is_primary,
                .name = name_buf,
                .name_len = name_len,
            };
        }

        // Reorder so primary is first (index 0)
        if (primary_idx != 0) {
            const tmp = result[0];
            result[0] = result[primary_idx];
            result[primary_idx] = tmp;
            result[0].id = 0;
            result[primary_idx].id = primary_idx;
        }

        return result;
    }

    /// Get a specific monitor by index
    pub fn getMonitor(self: XRandRConnection, index: u32) !MonitorInfo {
        const monitors = try self.getMonitors();
        defer self.allocator.free(monitors);

        if (index >= monitors.len) {
            return error.InvalidMonitorIndex;
        }

        return monitors[index];
    }

    /// Get the primary monitor
    pub fn getPrimaryMonitor(self: XRandRConnection) !MonitorInfo {
        return self.getMonitor(0);
    }

    /// Find which monitor contains a point
    pub fn getMonitorForPoint(self: XRandRConnection, point: Point) !?MonitorInfo {
        const monitors = try self.getMonitors();
        defer self.allocator.free(monitors);

        for (monitors) |mon| {
            if (mon.bounds.contains(point)) {
                return mon;
            }
        }
        return null;
    }

    /// Get combined bounds of all monitors (virtual screen)
    pub fn getVirtualScreenBounds(self: XRandRConnection) !Rectangle {
        const monitors = try self.getMonitors();
        defer self.allocator.free(monitors);

        if (monitors.len == 0) {
            return error.NoMonitors;
        }

        var min_x: i32 = std.math.maxInt(i32);
        var min_y: i32 = std.math.maxInt(i32);
        var max_x: i32 = std.math.minInt(i32);
        var max_y: i32 = std.math.minInt(i32);

        for (monitors) |mon| {
            min_x = @min(min_x, mon.bounds.x);
            min_y = @min(min_y, mon.bounds.y);
            max_x = @max(max_x, mon.bounds.right());
            max_y = @max(max_y, mon.bounds.bottom());
        }

        return Rectangle.init(
            min_x,
            min_y,
            @intCast(max_x - min_x),
            @intCast(max_y - min_y),
        );
    }
};

// Tests
test "XRandR: compile check" {
    _ = XRandRConnection;
    _ = MonitorInfo;
}
