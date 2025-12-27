//! Verification Layer for Virtual Tests
//!
//! Provides methods to verify that Zikuli operations produced
//! the expected results in the virtual environment.
//!
//! Usage:
//!   var verifier = Verifier.init(allocator);
//!   defer verifier.deinit();
//!
//!   // Verify mouse position
//!   try verifier.expectMouseAt(100, 200, 5);
//!
//!   // Verify pixel color at location
//!   try verifier.expectColorAt(100, 200, 255, 0, 0);

const std = @import("std");

// XCB C bindings for direct X11 access
const x11 = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/shm.h");
    @cInclude("xcb/xcb_image.h");
});

/// Verification utilities for test assertions
pub const Verifier = struct {
    allocator: std.mem.Allocator,
    conn: *x11.xcb_connection_t,
    screen: *x11.xcb_screen_t,

    pub fn init(allocator: std.mem.Allocator) !Verifier {
        var screen_num: c_int = 0;
        const conn = x11.xcb_connect(null, &screen_num);
        if (conn == null or x11.xcb_connection_has_error(conn) != 0) {
            return error.ConnectionFailed;
        }

        const setup = x11.xcb_get_setup(conn);
        var iter = x11.xcb_setup_roots_iterator(setup);
        var i: c_int = 0;
        while (i < screen_num) : (i += 1) {
            x11.xcb_screen_next(&iter);
        }

        return Verifier{
            .allocator = allocator,
            .conn = conn.?,
            .screen = iter.data.?,
        };
    }

    pub fn deinit(self: *Verifier) void {
        x11.xcb_disconnect(self.conn);
    }

    /// Verify mouse is at expected position (with tolerance)
    pub fn expectMouseAt(self: *Verifier, expected_x: i32, expected_y: i32, tolerance: u32) !void {
        const pos = try self.getMousePosition();

        const dx = @abs(pos.x - expected_x);
        const dy = @abs(pos.y - expected_y);

        if (dx > tolerance or dy > tolerance) {
            std.debug.print(
                "Mouse position mismatch: expected ({}, {}), got ({}, {}), tolerance={}\n",
                .{ expected_x, expected_y, pos.x, pos.y, tolerance },
            );
            return error.PositionMismatch;
        }
    }

    /// Get current mouse position
    pub fn getMousePosition(self: *Verifier) !struct { x: i32, y: i32 } {
        const cookie = x11.xcb_query_pointer(self.conn, self.screen.root);
        const reply = x11.xcb_query_pointer_reply(self.conn, cookie, null);

        if (reply) |r| {
            defer std.c.free(r);
            return .{ .x = r.root_x, .y = r.root_y };
        }

        return error.QueryFailed;
    }

    /// Verify pixel color at location matches expected (with tolerance)
    pub fn expectColorAt(
        self: *Verifier,
        x: i16,
        y: i16,
        expected_r: u8,
        expected_g: u8,
        expected_b: u8,
        tolerance: u8,
    ) !void {
        const color = try self.getPixelColor(x, y);

        const dr = @as(i16, color.r) - @as(i16, expected_r);
        const dg = @as(i16, color.g) - @as(i16, expected_g);
        const db = @as(i16, color.b) - @as(i16, expected_b);

        if (@abs(dr) > tolerance or @abs(dg) > tolerance or @abs(db) > tolerance) {
            std.debug.print(
                "Color mismatch at ({}, {}): expected RGB({}, {}, {}), got RGB({}, {}, {}), tolerance={}\n",
                .{ x, y, expected_r, expected_g, expected_b, color.r, color.g, color.b, tolerance },
            );
            return error.ColorMismatch;
        }
    }

    /// Get pixel color at location
    pub fn getPixelColor(self: *Verifier, x: i16, y: i16) !struct { r: u8, g: u8, b: u8 } {
        const cookie = x11.xcb_get_image(
            self.conn,
            x11.XCB_IMAGE_FORMAT_Z_PIXMAP,
            self.screen.root,
            x,
            y,
            1,
            1,
            0xFFFFFFFF,
        );

        const reply = x11.xcb_get_image_reply(self.conn, cookie, null);
        if (reply) |r| {
            defer std.c.free(r);
            const data = x11.xcb_get_image_data(r);
            const len = x11.xcb_get_image_data_length(r);

            if (len >= 3) {
                // X11 typically returns BGRA or BGR
                return .{
                    .r = data[2],
                    .g = data[1],
                    .b = data[0],
                };
            }
        }

        return error.GetPixelFailed;
    }

    /// Verify that a region contains a specific pattern
    pub fn expectPatternInRegion(
        self: *Verifier,
        region_x: i16,
        region_y: i16,
        region_width: u16,
        region_height: u16,
        expected_color: struct { r: u8, g: u8, b: u8 },
        min_coverage: f32,
    ) !void {
        var matching_pixels: u32 = 0;
        const total_pixels = @as(u32, region_width) * @as(u32, region_height);

        var y: u16 = 0;
        while (y < region_height) : (y += 1) {
            var x: u16 = 0;
            while (x < region_width) : (x += 1) {
                const color = self.getPixelColor(
                    region_x + @as(i16, @intCast(x)),
                    region_y + @as(i16, @intCast(y)),
                ) catch continue;

                if (color.r == expected_color.r and
                    color.g == expected_color.g and
                    color.b == expected_color.b)
                {
                    matching_pixels += 1;
                }
            }
        }

        const coverage = @as(f32, @floatFromInt(matching_pixels)) / @as(f32, @floatFromInt(total_pixels));

        if (coverage < min_coverage) {
            std.debug.print(
                "Pattern coverage too low: expected >= {d:.2}, got {d:.2}\n",
                .{ min_coverage, coverage },
            );
            return error.InsufficientCoverage;
        }
    }

    /// Capture a region for comparison
    pub fn captureRegion(self: *Verifier, x: i16, y: i16, width: u16, height: u16) ![]u8 {
        const cookie = x11.xcb_get_image(
            self.conn,
            x11.XCB_IMAGE_FORMAT_Z_PIXMAP,
            self.screen.root,
            x,
            y,
            width,
            height,
            0xFFFFFFFF,
        );

        const reply = x11.xcb_get_image_reply(self.conn, cookie, null);
        if (reply) |r| {
            defer std.c.free(r);
            const data = x11.xcb_get_image_data(r);
            const len = x11.xcb_get_image_data_length(r);

            const result = try self.allocator.alloc(u8, @intCast(len));
            @memcpy(result, data[0..@intCast(len)]);
            return result;
        }

        return error.CaptureFailed;
    }

    /// Compare two captured regions
    pub fn compareRegions(self: *Verifier, region1: []const u8, region2: []const u8) f32 {
        _ = self;
        if (region1.len != region2.len) return 0.0;
        if (region1.len == 0) return 1.0;

        var matching: u32 = 0;
        for (region1, region2) |a, b| {
            if (a == b) matching += 1;
        }

        return @as(f32, @floatFromInt(matching)) / @as(f32, @floatFromInt(region1.len));
    }
};

/// Result of a find operation for verification
pub const FindResult = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,
    similarity: f32,
};

/// Verify that Zikuli's find operation returns expected location
pub fn verifyFindResult(
    result: FindResult,
    expected_x: i32,
    expected_y: i32,
    tolerance: u32,
    min_similarity: f32,
) !void {
    // Check similarity threshold
    if (result.similarity < min_similarity) {
        std.debug.print(
            "Find similarity too low: expected >= {d:.2}, got {d:.2}\n",
            .{ min_similarity, result.similarity },
        );
        return error.SimilarityTooLow;
    }

    // Check position
    const dx = @abs(result.x - expected_x);
    const dy = @abs(result.y - expected_y);

    if (dx > tolerance or dy > tolerance) {
        std.debug.print(
            "Find position mismatch: expected ({}, {}), got ({}, {}), tolerance={}\n",
            .{ expected_x, expected_y, result.x, result.y, tolerance },
        );
        return error.PositionMismatch;
    }
}

// ============================================================================
// Tests
// ============================================================================

test "Verifier: basic functionality" {
    const allocator = std.testing.allocator;

    var verifier = Verifier.init(allocator) catch |err| {
        if (err == error.ConnectionFailed) {
            std.debug.print("Skipping test: No X11 display available\n", .{});
            return;
        }
        return err;
    };
    defer verifier.deinit();

    // Just verify we can query mouse position
    const pos = try verifier.getMousePosition();
    try std.testing.expect(pos.x >= 0);
    try std.testing.expect(pos.y >= 0);
}
