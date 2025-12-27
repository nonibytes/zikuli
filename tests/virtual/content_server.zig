//! Test Content Server
//!
//! Places test content (images, colors, patterns) at exact pixel coordinates
//! on an X11 display. Uses override-redirect windows to bypass window manager.
//!
//! Usage:
//!   var server = try ContentServer.init(allocator);
//!   defer server.deinit();
//!
//!   var win = try server.createWindow(100, 200, 50, 50);
//!   win.fillColor(255, 0, 0);  // Red
//!   win.map();

const std = @import("std");

// XCB C bindings for direct X11 access
// Made public so event_tracker.zig can use the same types
pub const x11 = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/shm.h");
    @cInclude("xcb/xcb_image.h");
});

/// Test content server for placing content at exact coordinates
pub const ContentServer = struct {
    allocator: std.mem.Allocator,
    conn: *x11.xcb_connection_t,
    screen: *x11.xcb_screen_t,
    windows: std.ArrayList(Window),
    gc: x11.xcb_gcontext_t,

    pub fn init(allocator: std.mem.Allocator) !ContentServer {
        // Connect to X11
        var screen_num: c_int = 0;
        const conn = x11.xcb_connect(null, &screen_num);
        if (conn == null or x11.xcb_connection_has_error(conn) != 0) {
            return error.ConnectionFailed;
        }

        // Get screen
        const setup = x11.xcb_get_setup(conn);
        var iter = x11.xcb_setup_roots_iterator(setup);
        var i: c_int = 0;
        while (i < screen_num) : (i += 1) {
            x11.xcb_screen_next(&iter);
        }
        const screen = iter.data;

        // Create graphics context
        const gc = x11.xcb_generate_id(conn);
        const gc_values = [_]u32{ screen.*.black_pixel, screen.*.white_pixel };
        _ = x11.xcb_create_gc(conn, gc, screen.*.root, x11.XCB_GC_FOREGROUND | x11.XCB_GC_BACKGROUND, &gc_values);

        return ContentServer{
            .allocator = allocator,
            .conn = conn.?,
            .screen = screen.?,
            .windows = .empty,
            .gc = gc,
        };
    }

    pub fn deinit(self: *ContentServer) void {
        // Destroy all windows
        for (self.windows.items) |*win| {
            win.destroy();
        }
        self.windows.deinit(self.allocator);

        // Free GC and disconnect
        _ = x11.xcb_free_gc(self.conn, self.gc);
        x11.xcb_disconnect(self.conn);
    }

    /// Create a window at exact coordinates (override-redirect, no WM)
    pub fn createWindow(self: *ContentServer, x: i16, y: i16, width: u16, height: u16) !*Window {
        const win_id = x11.xcb_generate_id(self.conn);

        // Override-redirect = 1 means window manager won't touch it
        const value_mask = x11.XCB_CW_BACK_PIXEL | x11.XCB_CW_OVERRIDE_REDIRECT;
        const values = [_]u32{ self.screen.white_pixel, 1 };

        _ = x11.xcb_create_window(
            self.conn,
            x11.XCB_COPY_FROM_PARENT,
            win_id,
            self.screen.root,
            x,
            y,
            width,
            height,
            0, // border width
            x11.XCB_WINDOW_CLASS_INPUT_OUTPUT,
            self.screen.root_visual,
            value_mask,
            &values,
        );

        const window = try self.windows.addOne(self.allocator);
        window.* = Window{
            .id = win_id,
            .conn = self.conn,
            .gc = self.gc,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .mapped = false,
        };

        return window;
    }

    /// Get screen dimensions
    pub fn getScreenSize(self: *ContentServer) struct { width: u16, height: u16 } {
        return .{
            .width = self.screen.width_in_pixels,
            .height = self.screen.height_in_pixels,
        };
    }

    /// Flush all pending X11 operations
    pub fn flush(self: *ContentServer) void {
        _ = x11.xcb_flush(self.conn);
    }

    /// Sync - wait for all operations to complete
    pub fn sync(self: *ContentServer) void {
        // Get a reply to force sync
        const cookie = x11.xcb_get_input_focus(self.conn);
        const reply = x11.xcb_get_input_focus_reply(self.conn, cookie, null);
        if (reply) |r| {
            std.c.free(r);
        }
    }
};

/// A test window at exact coordinates
pub const Window = struct {
    id: x11.xcb_window_t,
    conn: *x11.xcb_connection_t,
    gc: x11.xcb_gcontext_t,
    x: i16,
    y: i16,
    width: u16,
    height: u16,
    mapped: bool,

    /// Fill window with solid color
    pub fn fillColor(self: *Window, r: u8, g: u8, b: u8) void {
        // Convert RGB to X11 pixel value (assuming TrueColor visual)
        const pixel: u32 = (@as(u32, r) << 16) | (@as(u32, g) << 8) | @as(u32, b);

        // Change window background
        _ = x11.xcb_change_window_attributes(
            self.conn,
            self.id,
            x11.XCB_CW_BACK_PIXEL,
            &[_]u32{pixel},
        );

        // Clear to show new background
        _ = x11.xcb_clear_area(self.conn, 0, self.id, 0, 0, self.width, self.height);
    }

    /// Draw image data to window
    pub fn drawImage(self: *Window, data: []const u8, img_width: u16, img_height: u16) void {
        _ = x11.xcb_put_image(
            self.conn,
            x11.XCB_IMAGE_FORMAT_Z_PIXMAP,
            self.id,
            self.gc,
            img_width,
            img_height,
            0,
            0,
            0,
            24, // depth
            @intCast(data.len),
            data.ptr,
        );
    }

    /// Map (show) window
    pub fn map(self: *Window) void {
        _ = x11.xcb_map_window(self.conn, self.id);
        self.mapped = true;
        _ = x11.xcb_flush(self.conn);
    }

    /// Unmap (hide) window
    pub fn unmap(self: *Window) void {
        _ = x11.xcb_unmap_window(self.conn, self.id);
        self.mapped = false;
        _ = x11.xcb_flush(self.conn);
    }

    /// Destroy window
    pub fn destroy(self: *Window) void {
        _ = x11.xcb_destroy_window(self.conn, self.id);
        _ = x11.xcb_flush(self.conn);
    }

    /// Get center point
    pub fn center(self: Window) struct { x: i32, y: i32 } {
        return .{
            .x = @as(i32, self.x) + @divTrunc(@as(i32, self.width), 2),
            .y = @as(i32, self.y) + @divTrunc(@as(i32, self.height), 2),
        };
    }
};

/// Placed content info for verification
pub const PlacedContent = struct {
    window: *Window,
    description: []const u8,
    expected_color: ?struct { r: u8, g: u8, b: u8 } = null,
};

// ============================================================================
// Tests
// ============================================================================

test "ContentServer: create and fill window" {
    // This test requires X11 display
    const allocator = std.testing.allocator;

    var server = ContentServer.init(allocator) catch |err| {
        // Skip test if no display
        if (err == error.ConnectionFailed) {
            std.debug.print("Skipping test: No X11 display available\n", .{});
            return;
        }
        return err;
    };
    defer server.deinit();

    // Get screen size
    const size = server.getScreenSize();
    try std.testing.expect(size.width > 0);
    try std.testing.expect(size.height > 0);

    // Create window
    var win = try server.createWindow(100, 100, 50, 50);
    win.fillColor(255, 0, 0); // Red
    win.map();

    server.sync();

    // Window should be at expected position
    try std.testing.expectEqual(@as(i16, 100), win.x);
    try std.testing.expectEqual(@as(i16, 100), win.y);
    try std.testing.expectEqual(@as(u16, 50), win.width);
    try std.testing.expectEqual(@as(u16, 50), win.height);
}
