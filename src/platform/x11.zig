//! X11/XCB Screen Capture for Zikuli
//!
//! Provides low-level X11 screen capture using XCB.
//! Uses xcb_get_image() for screenshot capture.
//!
//! Based on SikuliX ScreenDevice.java analysis:
//! - Multi-monitor support via screen enumeration
//! - Primary screen contains point (0,0)
//! - Capture returns raw pixel data (BGRA format from X11)

const std = @import("std");
const geometry = @import("../geometry.zig");
const Rectangle = geometry.Rectangle;
const Point = geometry.Point;

// XCB C bindings
const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/shm.h");
});

/// X11 connection and screen information
pub const X11Connection = struct {
    connection: *c.xcb_connection_t,
    screen: *c.xcb_screen_t,
    screen_num: i32,

    /// Connect to X11 display
    pub fn connect(display_name: ?[*:0]const u8) !X11Connection {
        var screen_num: c_int = 0;
        const conn = c.xcb_connect(display_name, &screen_num);

        if (conn == null) {
            return error.ConnectionFailed;
        }

        const err = c.xcb_connection_has_error(conn);
        if (err != 0) {
            c.xcb_disconnect(conn);
            return error.ConnectionFailed;
        }

        // Get screen
        const setup = c.xcb_get_setup(conn);
        if (setup == null) {
            c.xcb_disconnect(conn);
            return error.SetupFailed;
        }

        var iter = c.xcb_setup_roots_iterator(setup);
        var i: c_int = 0;
        while (i < screen_num) : (i += 1) {
            c.xcb_screen_next(&iter);
        }

        const screen = iter.data;
        if (screen == null) {
            c.xcb_disconnect(conn);
            return error.NoScreen;
        }

        return .{
            .connection = conn.?,
            .screen = screen.?,
            .screen_num = screen_num,
        };
    }

    /// Connect to default display
    pub fn connectDefault() !X11Connection {
        return connect(null);
    }

    /// Disconnect from X11
    pub fn disconnect(self: *X11Connection) void {
        c.xcb_disconnect(self.connection);
    }

    /// Get screen width
    pub fn getScreenWidth(self: X11Connection) u32 {
        return self.screen.width_in_pixels;
    }

    /// Get screen height
    pub fn getScreenHeight(self: X11Connection) u32 {
        return self.screen.height_in_pixels;
    }

    /// Get screen bounds as Rectangle
    pub fn getScreenBounds(self: X11Connection) Rectangle {
        return Rectangle.init(
            0,
            0,
            self.screen.width_in_pixels,
            self.screen.height_in_pixels,
        );
    }

    /// Get root window
    pub fn getRootWindow(self: X11Connection) c.xcb_window_t {
        return self.screen.root;
    }

    /// Get screen depth
    pub fn getDepth(self: X11Connection) u8 {
        return self.screen.root_depth;
    }

    /// Capture a region of the screen
    /// Returns raw pixel data in BGRA format (X11 native)
    /// Caller owns the returned memory
    pub fn captureRegion(self: X11Connection, allocator: std.mem.Allocator, rect: Rectangle) !CapturedImage {
        // Validate rectangle
        if (rect.width == 0 or rect.height == 0) {
            return error.InvalidRegion;
        }

        // Clamp to screen bounds
        const screen_bounds = self.getScreenBounds();
        const clamped = rect.intersection(screen_bounds);
        if (clamped.isEmpty()) {
            return error.RegionOutOfBounds;
        }

        // Request image from X server
        const cookie = c.xcb_get_image(
            self.connection,
            c.XCB_IMAGE_FORMAT_Z_PIXMAP,
            self.screen.root,
            @intCast(clamped.x),
            @intCast(clamped.y),
            @intCast(clamped.width),
            @intCast(clamped.height),
            ~@as(u32, 0), // All planes
        );

        const reply = c.xcb_get_image_reply(self.connection, cookie, null);
        if (reply == null) {
            return error.CaptureError;
        }
        defer std.c.free(reply);

        // Get image data
        const data_ptr = c.xcb_get_image_data(reply);
        if (data_ptr == null) {
            return error.NoImageData;
        }

        const data_len = c.xcb_get_image_data_length(reply);
        if (data_len <= 0) {
            return error.NoImageData;
        }

        // Calculate expected size (4 bytes per pixel for 32-bit depth)
        const expected_size = @as(usize, clamped.width) * @as(usize, clamped.height) * 4;
        const actual_len: usize = @intCast(data_len);

        if (actual_len < expected_size) {
            return error.IncompleteData;
        }

        // Copy data to managed memory
        const pixels = try allocator.alloc(u8, expected_size);
        errdefer allocator.free(pixels);

        @memcpy(pixels, data_ptr[0..expected_size]);

        return CapturedImage{
            .pixels = pixels,
            .width = clamped.width,
            .height = clamped.height,
            .stride = clamped.width * 4,
            .depth = reply.*.depth,
            .format = .BGRA,
            .allocator = allocator,
        };
    }

    /// Capture full screen
    pub fn captureFullScreen(self: X11Connection, allocator: std.mem.Allocator) !CapturedImage {
        return self.captureRegion(allocator, self.getScreenBounds());
    }

    /// Flush pending requests
    pub fn flush(self: X11Connection) void {
        _ = c.xcb_flush(self.connection);
    }
};

/// Pixel format of captured image
pub const PixelFormat = enum {
    BGRA, // X11 native (Blue, Green, Red, Alpha)
    RGBA, // Standard (Red, Green, Blue, Alpha)
    RGB, // No alpha
    BGR, // No alpha, reversed
};

/// A captured screen image
pub const CapturedImage = struct {
    pixels: []u8,
    width: u32,
    height: u32,
    stride: u32, // Bytes per row
    depth: u8, // Bits per pixel
    format: PixelFormat,
    allocator: std.mem.Allocator,

    /// Free the captured image
    pub fn deinit(self: *CapturedImage) void {
        self.allocator.free(self.pixels);
    }

    /// Get pixel at (x, y) as RGBA tuple
    pub fn getPixel(self: CapturedImage, x: u32, y: u32) ?struct { r: u8, g: u8, b: u8, a: u8 } {
        if (x >= self.width or y >= self.height) {
            return null;
        }

        const offset = y * self.stride + x * 4;
        if (offset + 3 >= self.pixels.len) {
            return null;
        }

        // X11 BGRA format
        return .{
            .r = self.pixels[offset + 2],
            .g = self.pixels[offset + 1],
            .b = self.pixels[offset + 0],
            .a = self.pixels[offset + 3],
        };
    }

    /// Convert BGRA to RGBA in place
    pub fn convertToRGBA(self: *CapturedImage) void {
        if (self.format == .RGBA) return;

        var i: usize = 0;
        while (i + 3 < self.pixels.len) : (i += 4) {
            const b = self.pixels[i];
            const r = self.pixels[i + 2];
            self.pixels[i] = r;
            self.pixels[i + 2] = b;
        }
        self.format = .RGBA;
    }

    /// Get bytes per pixel
    pub fn bytesPerPixel(self: CapturedImage) u32 {
        return switch (self.format) {
            .BGRA, .RGBA => 4,
            .BGR, .RGB => 3,
        };
    }

    /// Get total size in bytes
    pub fn size(self: CapturedImage) usize {
        return self.pixels.len;
    }
};

// ============================================================================
// Error Types
// ============================================================================

pub const X11Error = error{
    ConnectionFailed,
    SetupFailed,
    NoScreen,
    InvalidRegion,
    RegionOutOfBounds,
    CaptureError,
    NoImageData,
    IncompleteData,
};

// ============================================================================
// TESTS
// ============================================================================

test "X11Connection: can compile" {
    // This test just verifies the module compiles correctly
    // Actual X11 tests require a running X server
    _ = X11Connection;
    _ = CapturedImage;
    _ = PixelFormat;
}

test "CapturedImage: getPixel bounds check" {
    const allocator = std.testing.allocator;

    // Create a small test image (2x2 pixels, BGRA)
    var pixels = try allocator.alloc(u8, 16); // 2*2*4 = 16 bytes
    defer allocator.free(pixels);

    // Fill with test data: B, G, R, A pattern
    pixels[0] = 255;
    pixels[1] = 0;
    pixels[2] = 0;
    pixels[3] = 255; // Blue pixel
    pixels[4] = 0;
    pixels[5] = 255;
    pixels[6] = 0;
    pixels[7] = 255; // Green pixel
    pixels[8] = 0;
    pixels[9] = 0;
    pixels[10] = 255;
    pixels[11] = 255; // Red pixel
    pixels[12] = 255;
    pixels[13] = 255;
    pixels[14] = 255;
    pixels[15] = 255; // White pixel

    var img = CapturedImage{
        .pixels = pixels,
        .width = 2,
        .height = 2,
        .stride = 8,
        .depth = 32,
        .format = .BGRA,
        .allocator = allocator,
    };

    // Don't call deinit since we're managing memory ourselves

    // Test pixel 0,0 (should be blue in RGBA)
    const p00 = img.getPixel(0, 0);
    try std.testing.expect(p00 != null);
    try std.testing.expectEqual(@as(u8, 0), p00.?.r);
    try std.testing.expectEqual(@as(u8, 0), p00.?.g);
    try std.testing.expectEqual(@as(u8, 255), p00.?.b);

    // Test pixel 1,0 (should be green)
    const p10 = img.getPixel(1, 0);
    try std.testing.expect(p10 != null);
    try std.testing.expectEqual(@as(u8, 0), p10.?.r);
    try std.testing.expectEqual(@as(u8, 255), p10.?.g);
    try std.testing.expectEqual(@as(u8, 0), p10.?.b);

    // Test out of bounds
    try std.testing.expect(img.getPixel(5, 5) == null);
}

test "CapturedImage: convertToRGBA" {
    const allocator = std.testing.allocator;

    // Create test image with BGRA data
    var pixels = try allocator.alloc(u8, 4);
    defer allocator.free(pixels);

    pixels[0] = 10; // B
    pixels[1] = 20; // G
    pixels[2] = 30; // R
    pixels[3] = 255; // A

    var img = CapturedImage{
        .pixels = pixels,
        .width = 1,
        .height = 1,
        .stride = 4,
        .depth = 32,
        .format = .BGRA,
        .allocator = allocator,
    };

    img.convertToRGBA();

    // After conversion: R, G, B, A
    try std.testing.expectEqual(@as(u8, 30), img.pixels[0]); // R
    try std.testing.expectEqual(@as(u8, 20), img.pixels[1]); // G
    try std.testing.expectEqual(@as(u8, 10), img.pixels[2]); // B
    try std.testing.expectEqual(@as(u8, 255), img.pixels[3]); // A
    try std.testing.expectEqual(PixelFormat.RGBA, img.format);
}
