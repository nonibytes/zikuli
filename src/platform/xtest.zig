//! XTest Extension Bindings for Zikuli
//!
//! Provides low-level bindings to the X11 XTest extension for synthetic input.
//! Uses Xlib (not XCB) as XTest is only available through Xlib.
//!
//! Key XTest functions:
//! - XTestFakeMotionEvent: Move mouse cursor
//! - XTestFakeButtonEvent: Press/release mouse button
//! - XTestFakeKeyEvent: Press/release keyboard key
//!
//! Reference: https://www.x.org/releases/X11R7.7/doc/libXtst/

const std = @import("std");
const geometry = @import("../geometry.zig");
const Point = geometry.Point;

// Xlib and XTest C bindings
pub const c = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/extensions/XTest.h");
});

/// X11/XTest connection wrapper
pub const XTestConnection = struct {
    display: *c.Display,
    screen: c_int,
    root: c.Window,
    owns_display: bool,

    /// Connect to X11 display and verify XTest extension
    pub fn connect(display_name: ?[*:0]const u8) !XTestConnection {
        const dpy = c.XOpenDisplay(display_name);
        if (dpy == null) {
            return error.DisplayOpenFailed;
        }
        errdefer _ = c.XCloseDisplay(dpy);

        // Verify XTest extension is available
        var event_base: c_int = undefined;
        var error_base: c_int = undefined;
        var major: c_int = undefined;
        var minor: c_int = undefined;

        if (c.XTestQueryExtension(dpy, &event_base, &error_base, &major, &minor) == 0) {
            return error.XTestNotAvailable;
        }

        const screen_num = c.DefaultScreen(dpy);
        const root = c.RootWindow(dpy, screen_num);

        return .{
            .display = dpy.?,
            .screen = screen_num,
            .root = root,
            .owns_display = true,
        };
    }

    /// Connect to default display
    pub fn connectDefault() !XTestConnection {
        return connect(null);
    }

    /// Disconnect from X11
    pub fn disconnect(self: *XTestConnection) void {
        if (self.owns_display) {
            _ = c.XCloseDisplay(self.display);
        }
    }

    /// Get screen width
    pub fn getScreenWidth(self: XTestConnection) u32 {
        return @intCast(c.DisplayWidth(self.display, self.screen));
    }

    /// Get screen height
    pub fn getScreenHeight(self: XTestConnection) u32 {
        return @intCast(c.DisplayHeight(self.display, self.screen));
    }

    /// Get current mouse position
    pub fn getMousePosition(self: XTestConnection) !Point {
        var root_return: c.Window = undefined;
        var child_return: c.Window = undefined;
        var root_x: c_int = undefined;
        var root_y: c_int = undefined;
        var win_x: c_int = undefined;
        var win_y: c_int = undefined;
        var mask: c_uint = undefined;

        const result = c.XQueryPointer(
            self.display,
            self.root,
            &root_return,
            &child_return,
            &root_x,
            &root_y,
            &win_x,
            &win_y,
            &mask,
        );

        if (result == 0) {
            return error.QueryPointerFailed;
        }

        return Point.init(root_x, root_y);
    }

    /// Move mouse to absolute position
    /// Uses screen_number -1 for multi-monitor setups (Xinerama/RandR)
    /// This tells XTest to use virtual screen coordinates
    pub fn moveMouse(self: XTestConnection, x: i32, y: i32) !void {
        const result = c.XTestFakeMotionEvent(
            self.display,
            -1, // -1 = current screen (works with multi-monitor Xinerama/RandR)
            x,
            y,
            0, // delay in ms (0 = immediate)
        );

        if (result == 0) {
            return error.MotionEventFailed;
        }

        // Flush to ensure event is sent immediately
        _ = c.XFlush(self.display);
    }

    /// Move mouse relative to current position
    pub fn moveMouseRelative(self: XTestConnection, dx: i32, dy: i32) !void {
        const result = c.XTestFakeRelativeMotionEvent(
            self.display,
            dx,
            dy,
            0, // delay
        );

        if (result == 0) {
            return error.MotionEventFailed;
        }

        _ = c.XFlush(self.display);
    }

    /// Press or release a mouse button
    /// button: 1=left, 2=middle, 3=right, 4=wheel up, 5=wheel down
    pub fn mouseButton(self: XTestConnection, button: u32, is_press: bool) !void {
        const result = c.XTestFakeButtonEvent(
            self.display,
            @intCast(button),
            if (is_press) c.True else c.False,
            0, // delay
        );

        if (result == 0) {
            return error.ButtonEventFailed;
        }

        _ = c.XFlush(self.display);
    }

    /// Press a mouse button
    pub fn mouseDown(self: XTestConnection, button: u32) !void {
        return self.mouseButton(button, true);
    }

    /// Release a mouse button
    pub fn mouseUp(self: XTestConnection, button: u32) !void {
        return self.mouseButton(button, false);
    }

    /// Click a mouse button (press and release)
    pub fn mouseClick(self: XTestConnection, button: u32) !void {
        try self.mouseDown(button);
        try self.mouseUp(button);
    }

    /// Double click a mouse button
    pub fn mouseDoubleClick(self: XTestConnection, button: u32) !void {
        try self.mouseClick(button);
        // Small delay between clicks (XTest handles timing)
        std.Thread.sleep(50 * std.time.ns_per_ms);
        try self.mouseClick(button);
    }

    /// Scroll wheel
    /// direction: 4=up, 5=down
    /// steps: number of scroll steps
    pub fn mouseWheel(self: XTestConnection, direction: u32, steps: u32) !void {
        var i: u32 = 0;
        while (i < steps) : (i += 1) {
            try self.mouseClick(direction);
            std.Thread.sleep(50 * std.time.ns_per_ms); // Match SikuliX WHEEL_STEP_DELAY
        }
    }

    /// Press or release a key
    pub fn keyEvent(self: XTestConnection, keycode: u32, is_press: bool) !void {
        const result = c.XTestFakeKeyEvent(
            self.display,
            @intCast(keycode),
            if (is_press) c.True else c.False,
            0, // delay
        );

        if (result == 0) {
            return error.KeyEventFailed;
        }

        _ = c.XFlush(self.display);
    }

    /// Press a key
    pub fn keyDown(self: XTestConnection, keycode: u32) !void {
        return self.keyEvent(keycode, true);
    }

    /// Release a key
    pub fn keyUp(self: XTestConnection, keycode: u32) !void {
        return self.keyEvent(keycode, false);
    }

    /// Type a key (press and release)
    pub fn keyPress(self: XTestConnection, keycode: u32) !void {
        try self.keyDown(keycode);
        try self.keyUp(keycode);
    }

    /// Convert keysym to keycode
    pub fn keysymToKeycode(self: XTestConnection, keysym: c.KeySym) u32 {
        return c.XKeysymToKeycode(self.display, keysym);
    }

    /// Flush pending requests
    pub fn flush(self: XTestConnection) void {
        _ = c.XFlush(self.display);
    }

    /// Sync with X server (wait for all requests to complete)
    pub fn sync(self: XTestConnection) void {
        _ = c.XSync(self.display, c.False);
    }
};

/// XTest error types
pub const XTestError = error{
    DisplayOpenFailed,
    XTestNotAvailable,
    QueryPointerFailed,
    MotionEventFailed,
    ButtonEventFailed,
    KeyEventFailed,
};

// ============================================================================
// TESTS
// ============================================================================

test "XTestConnection: compile check" {
    _ = XTestConnection;
    _ = XTestError;
}

test "XTestConnection: can connect to display" {
    // This test requires a running X server
    // Skip if DISPLAY is not set
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        return; // Skip test - no display available
    }

    var conn = XTestConnection.connectDefault() catch |err| {
        // XTest might not be available in some environments
        if (err == error.XTestNotAvailable) {
            return; // Skip test
        }
        return err;
    };
    defer conn.disconnect();

    // Verify we can get screen dimensions
    const width = conn.getScreenWidth();
    const height = conn.getScreenHeight();
    try std.testing.expect(width > 0);
    try std.testing.expect(height > 0);
}

test "XTestConnection: can get mouse position" {
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        return;
    }

    var conn = XTestConnection.connectDefault() catch |err| {
        if (err == error.XTestNotAvailable) return;
        return err;
    };
    defer conn.disconnect();

    const pos = try conn.getMousePosition();

    // Position should be within screen bounds
    const width: i32 = @intCast(conn.getScreenWidth());
    const height: i32 = @intCast(conn.getScreenHeight());

    try std.testing.expect(pos.x >= 0);
    try std.testing.expect(pos.y >= 0);
    try std.testing.expect(pos.x < width);
    try std.testing.expect(pos.y < height);
}
