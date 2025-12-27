//! Image handling for Zikuli
//!
//! Provides image loading, saving, and manipulation.
//! Supports PNG format using libpng.
//!
//! Based on SikuliX Image.java analysis:
//! - Images are primarily used as pattern references
//! - Support for PNG, JPG, and other formats
//! - lastSeen optimization (still-there cache)

const std = @import("std");
const geometry = @import("geometry.zig");
const x11 = @import("platform/x11.zig");
const Rectangle = geometry.Rectangle;
const Point = geometry.Point;
const CapturedImage = x11.CapturedImage;

// libpng and stdio C bindings
const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("png.h");
});

/// Pixel format for images
pub const PixelFormat = enum {
    RGBA, // Red, Green, Blue, Alpha (standard)
    BGRA, // Blue, Green, Red, Alpha (X11 native)
    RGB, // No alpha channel
    BGR, // No alpha, reversed
    Grayscale, // Single channel
};

/// An Image holds pixel data for visual matching
pub const Image = struct {
    /// Pixel data (owned memory)
    data: []u8,

    /// Image width in pixels
    width: u32,

    /// Image height in pixels
    height: u32,

    /// Bytes per row (may include padding)
    stride: u32,

    /// Pixel format
    format: PixelFormat,

    /// Memory allocator
    allocator: std.mem.Allocator,

    /// Optional path for pattern images
    path: ?[]const u8,

    /// Last location where this image was found (still-there optimization)
    last_seen: ?Rectangle,

    /// Create an empty image
    pub fn init(allocator: std.mem.Allocator, w: u32, h: u32, fmt: PixelFormat) !Image {
        const bpp = bytesPerPixelForFormat(fmt);
        const row_stride = w * bpp;
        const data_size = row_stride * h;
        const data = try allocator.alloc(u8, data_size);
        @memset(data, 0);

        return Image{
            .data = data,
            .width = w,
            .height = h,
            .stride = row_stride,
            .format = fmt,
            .allocator = allocator,
            .path = null,
            .last_seen = null,
        };
    }

    /// Create image from raw pixel data (takes ownership)
    pub fn fromRawData(
        allocator: std.mem.Allocator,
        data: []u8,
        width: u32,
        height: u32,
        format: PixelFormat,
    ) Image {
        return Image{
            .data = data,
            .width = width,
            .height = height,
            .stride = width * bytesPerPixelForFormat(format),
            .format = format,
            .allocator = allocator,
            .path = null,
            .last_seen = null,
        };
    }

    /// Create image from captured screen image (copies data)
    /// Note: X11 captures often have alpha=0, so we fix it to 255 (opaque)
    pub fn fromCapture(allocator: std.mem.Allocator, captured: CapturedImage) !Image {
        const data = try allocator.alloc(u8, captured.pixels.len);
        @memcpy(data, captured.pixels);

        const format: PixelFormat = switch (captured.format) {
            .BGRA => .BGRA,
            .RGBA => .RGBA,
            .RGB => .RGB,
            .BGR => .BGR,
        };

        // Fix alpha channel for RGBA/BGRA formats (X11 sets alpha=0)
        if (format == .RGBA or format == .BGRA) {
            var i: usize = 3; // Start at first alpha byte
            while (i < data.len) : (i += 4) {
                data[i] = 255; // Set alpha to opaque
            }
        }

        return Image{
            .data = data,
            .width = captured.width,
            .height = captured.height,
            .stride = captured.stride,
            .format = format,
            .allocator = allocator,
            .path = null,
            .last_seen = null,
        };
    }

    /// Free the image
    pub fn deinit(self: *Image) void {
        self.allocator.free(self.data);
        if (self.path) |p| {
            self.allocator.free(p);
        }
    }

    /// Get bytes per pixel for format
    pub fn bytesPerPixel(self: Image) u32 {
        return bytesPerPixelForFormat(self.format);
    }

    /// Get total size in bytes
    pub fn size(self: Image) usize {
        return self.data.len;
    }

    /// Get pixel at (x, y) as RGBA
    pub fn getPixel(self: Image, x: u32, y: u32) ?struct { r: u8, g: u8, b: u8, a: u8 } {
        if (x >= self.width or y >= self.height) return null;

        const bpp = self.bytesPerPixel();
        const offset = y * self.stride + x * bpp;

        if (offset + bpp - 1 >= self.data.len) return null;

        return switch (self.format) {
            .RGBA => .{
                .r = self.data[offset],
                .g = self.data[offset + 1],
                .b = self.data[offset + 2],
                .a = self.data[offset + 3],
            },
            .BGRA => .{
                .r = self.data[offset + 2],
                .g = self.data[offset + 1],
                .b = self.data[offset],
                .a = self.data[offset + 3],
            },
            .RGB => .{
                .r = self.data[offset],
                .g = self.data[offset + 1],
                .b = self.data[offset + 2],
                .a = 255,
            },
            .BGR => .{
                .r = self.data[offset + 2],
                .g = self.data[offset + 1],
                .b = self.data[offset],
                .a = 255,
            },
            .Grayscale => .{
                .r = self.data[offset],
                .g = self.data[offset],
                .b = self.data[offset],
                .a = 255,
            },
        };
    }

    /// Set pixel at (x, y)
    pub fn setPixel(self: *Image, x: u32, y: u32, r: u8, g: u8, b: u8, a: u8) void {
        if (x >= self.width or y >= self.height) return;

        const bpp = self.bytesPerPixel();
        const offset = y * self.stride + x * bpp;

        if (offset + bpp - 1 >= self.data.len) return;

        switch (self.format) {
            .RGBA => {
                self.data[offset] = r;
                self.data[offset + 1] = g;
                self.data[offset + 2] = b;
                self.data[offset + 3] = a;
            },
            .BGRA => {
                self.data[offset] = b;
                self.data[offset + 1] = g;
                self.data[offset + 2] = r;
                self.data[offset + 3] = a;
            },
            .RGB => {
                self.data[offset] = r;
                self.data[offset + 1] = g;
                self.data[offset + 2] = b;
            },
            .BGR => {
                self.data[offset] = b;
                self.data[offset + 1] = g;
                self.data[offset + 2] = r;
            },
            .Grayscale => {
                // Convert to grayscale using standard luminance weights
                const gray: u8 = @intFromFloat(
                    @as(f32, @floatFromInt(r)) * 0.299 +
                        @as(f32, @floatFromInt(g)) * 0.587 +
                        @as(f32, @floatFromInt(b)) * 0.114,
                );
                self.data[offset] = gray;
            },
        }
    }

    /// Convert to RGBA format in place
    pub fn convertToRGBA(self: *Image) void {
        if (self.format == .RGBA) return;

        if (self.format == .BGRA) {
            // Swap R and B channels
            var i: usize = 0;
            while (i + 3 < self.data.len) : (i += 4) {
                const b = self.data[i];
                const r = self.data[i + 2];
                self.data[i] = r;
                self.data[i + 2] = b;
            }
            self.format = .RGBA;
        }
        // Other conversions would require reallocation
    }

    /// Convert to BGRA format in place
    pub fn convertToBGRA(self: *Image) void {
        if (self.format == .BGRA) return;

        if (self.format == .RGBA) {
            // Swap R and B channels
            var i: usize = 0;
            while (i + 3 < self.data.len) : (i += 4) {
                const r = self.data[i];
                const b = self.data[i + 2];
                self.data[i] = b;
                self.data[i + 2] = r;
            }
            self.format = .BGRA;
        }
    }

    /// Get a sub-region of the image (copies data)
    pub fn getSubImage(self: Image, rect: Rectangle) !Image {
        // Clamp rectangle to image bounds
        const x: u32 = @intCast(@max(0, rect.x));
        const y: u32 = @intCast(@max(0, rect.y));
        const w = @min(rect.width, self.width -| x);
        const h = @min(rect.height, self.height -| y);

        if (w == 0 or h == 0) return error.InvalidRegion;

        const bpp = self.bytesPerPixel();
        var sub = try Image.init(self.allocator, w, h, self.format);

        // Copy row by row
        var row: u32 = 0;
        while (row < h) : (row += 1) {
            const src_offset = (y + row) * self.stride + x * bpp;
            const dst_offset = row * sub.stride;
            const copy_len = w * bpp;

            if (src_offset + copy_len <= self.data.len and
                dst_offset + copy_len <= sub.data.len)
            {
                @memcpy(
                    sub.data[dst_offset..][0..copy_len],
                    self.data[src_offset..][0..copy_len],
                );
            }
        }

        return sub;
    }

    /// Check if image is a "plain color" (solid fill)
    /// Uses same threshold as SikuliX: stddev < 1e-5
    pub fn isPlainColor(self: Image) bool {
        if (self.width == 0 or self.height == 0) return true;

        // Sample first pixel as reference
        const ref = self.getPixel(0, 0) orelse return true;

        // Check if all pixels match (simple check, not full stddev)
        var sample_count: u32 = 0;
        const step = @max(1, self.width * self.height / 100); // Sample ~100 pixels

        var i: u32 = 0;
        while (i < self.width * self.height) : (i += step) {
            const x = i % self.width;
            const y = i / self.width;
            if (self.getPixel(x, y)) |p| {
                if (p.r != ref.r or p.g != ref.g or p.b != ref.b) {
                    return false;
                }
                sample_count += 1;
            }
        }

        return sample_count > 0;
    }

    /// Get image bounds as Rectangle
    pub fn getBounds(self: Image) Rectangle {
        return Rectangle.init(0, 0, self.width, self.height);
    }

    /// Update last seen location (for still-there optimization)
    pub fn setLastSeen(self: *Image, rect: Rectangle) void {
        self.last_seen = rect;
    }

    /// Clear last seen location
    pub fn clearLastSeen(self: *Image) void {
        self.last_seen = null;
    }

    pub fn format_fn(
        self: Image,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Image({d}x{d}, {})", .{ self.width, self.height, self.format });
    }
};

/// Get bytes per pixel for a format
pub fn bytesPerPixelForFormat(format: PixelFormat) u32 {
    return switch (format) {
        .RGBA, .BGRA => 4,
        .RGB, .BGR => 3,
        .Grayscale => 1,
    };
}

/// Error types for image operations
pub const ImageError = error{
    InvalidRegion,
    FileNotFound,
    InvalidFormat,
    ReadError,
    WriteError,
    OutOfMemory,
};

// ============================================================================
// PNG I/O using libpng
// ============================================================================

/// Load image from PNG file
pub fn loadPng(allocator: std.mem.Allocator, path: []const u8) !Image {
    // Create null-terminated path
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);

    // Open file
    const file = c.fopen(path_z.ptr, "rb");
    if (file == null) {
        return error.FileNotFound;
    }
    defer _ = c.fclose(file);

    // Check PNG signature
    var sig: [8]u8 = undefined;
    if (c.fread(&sig, 1, 8, file) != 8) {
        return error.ReadError;
    }
    if (c.png_sig_cmp(&sig, 0, 8) != 0) {
        return error.InvalidFormat;
    }

    // Create read struct
    var png = c.png_create_read_struct(c.PNG_LIBPNG_VER_STRING, null, null, null);
    if (png == null) {
        return error.OutOfMemory;
    }
    defer c.png_destroy_read_struct(@ptrCast(&png), null, null);

    // Create info struct
    const info = c.png_create_info_struct(png);
    if (info == null) {
        return error.OutOfMemory;
    }

    // Initialize IO
    c.png_init_io(png, file);
    c.png_set_sig_bytes(png, 8);

    // Read info
    c.png_read_info(png, info);

    const width = c.png_get_image_width(png, info);
    const height = c.png_get_image_height(png, info);
    const color_type = c.png_get_color_type(png, info);
    const bit_depth = c.png_get_bit_depth(png, info);

    // Normalize to 8-bit RGBA
    if (bit_depth == 16) {
        c.png_set_strip_16(png);
    }
    if (color_type == c.PNG_COLOR_TYPE_PALETTE) {
        c.png_set_palette_to_rgb(png);
    }
    if (color_type == c.PNG_COLOR_TYPE_GRAY and bit_depth < 8) {
        c.png_set_expand_gray_1_2_4_to_8(png);
    }
    if (c.png_get_valid(png, info, c.PNG_INFO_tRNS) != 0) {
        c.png_set_tRNS_to_alpha(png);
    }
    if (color_type == c.PNG_COLOR_TYPE_RGB or
        color_type == c.PNG_COLOR_TYPE_GRAY or
        color_type == c.PNG_COLOR_TYPE_PALETTE)
    {
        c.png_set_filler(png, 0xFF, c.PNG_FILLER_AFTER);
    }
    if (color_type == c.PNG_COLOR_TYPE_GRAY or
        color_type == c.PNG_COLOR_TYPE_GRAY_ALPHA)
    {
        c.png_set_gray_to_rgb(png);
    }

    c.png_read_update_info(png, info);

    // Allocate memory
    const row_bytes = c.png_get_rowbytes(png, info);
    const data_size = row_bytes * height;
    const data = try allocator.alloc(u8, data_size);
    errdefer allocator.free(data);

    // Create row pointers
    const row_ptrs = try allocator.alloc([*c]u8, height);
    defer allocator.free(row_ptrs);

    for (0..height) |i| {
        row_ptrs[i] = data.ptr + i * row_bytes;
    }

    // Read image data
    c.png_read_image(png, @ptrCast(row_ptrs.ptr));
    c.png_read_end(png, null);

    return Image{
        .data = data,
        .width = @intCast(width),
        .height = @intCast(height),
        .stride = @intCast(row_bytes),
        .format = .RGBA,
        .allocator = allocator,
        .path = try allocator.dupe(u8, path),
        .last_seen = null,
    };
}

/// Save image to PNG file
pub fn savePng(image: *const Image, path: []const u8) !void {
    // Create null-terminated path
    var path_buf: [4096]u8 = undefined;
    if (path.len >= path_buf.len) {
        return error.WriteError;
    }
    @memcpy(path_buf[0..path.len], path);
    path_buf[path.len] = 0;

    // Open file
    const file = c.fopen(&path_buf, "wb");
    if (file == null) {
        return error.WriteError;
    }
    defer _ = c.fclose(file);

    // Create write struct
    var png = c.png_create_write_struct(c.PNG_LIBPNG_VER_STRING, null, null, null);
    if (png == null) {
        return error.OutOfMemory;
    }
    defer c.png_destroy_write_struct(@ptrCast(&png), null);

    // Create info struct
    const info = c.png_create_info_struct(png);
    if (info == null) {
        return error.OutOfMemory;
    }

    // Initialize IO
    c.png_init_io(png, file);

    // Determine color type based on format
    const color_type: c_int = switch (image.format) {
        .Grayscale => c.PNG_COLOR_TYPE_GRAY,
        .RGB, .BGR => c.PNG_COLOR_TYPE_RGB,
        .RGBA, .BGRA => c.PNG_COLOR_TYPE_RGBA,
    };

    // Set image info
    c.png_set_IHDR(
        png,
        info,
        @intCast(image.width),
        @intCast(image.height),
        8, // bit depth
        color_type,
        c.PNG_INTERLACE_NONE,
        c.PNG_COMPRESSION_TYPE_DEFAULT,
        c.PNG_FILTER_TYPE_DEFAULT,
    );

    // For BGR/BGRA, tell libpng to swap R and B
    if (image.format == .BGR or image.format == .BGRA) {
        c.png_set_bgr(png);
    }

    c.png_write_info(png, info);

    // Write image data row by row
    const bpp = image.bytesPerPixel();

    // For RGBA/BGRA, X11 often has alpha=0 which makes images transparent
    // We need to fix alpha to 255 (opaque) before writing
    if (image.format == .RGBA or image.format == .BGRA) {
        // Allocate a row buffer to fix alpha (max 4K width * 4 bytes = 16KB)
        var row_buf: [16384]u8 = undefined;
        const row_len = image.width * bpp;

        if (row_len <= row_buf.len) {
            var y: u32 = 0;
            while (y < image.height) : (y += 1) {
                const row_start = y * image.stride;
                if (row_start + row_len <= image.data.len) {
                    // Copy row and fix alpha channel
                    @memcpy(row_buf[0..row_len], image.data[row_start..][0..row_len]);

                    // Set alpha to 255 for each pixel
                    var x: u32 = 0;
                    while (x < image.width) : (x += 1) {
                        row_buf[x * 4 + 3] = 255;
                    }

                    c.png_write_row(png, &row_buf);
                }
            }
        } else {
            // Row too large for stack buffer, write without alpha fix
            var y: u32 = 0;
            while (y < image.height) : (y += 1) {
                const row_start = y * image.stride;
                const row_end = row_start + image.width * bpp;
                if (row_end <= image.data.len) {
                    c.png_write_row(png, image.data.ptr + row_start);
                }
            }
        }
    } else {
        // Non-alpha formats, write directly
        var y: u32 = 0;
        while (y < image.height) : (y += 1) {
            const row_start = y * image.stride;
            const row_end = row_start + image.width * bpp;
            if (row_end <= image.data.len) {
                c.png_write_row(png, image.data.ptr + row_start);
            }
        }
    }

    c.png_write_end(png, null);
}

// ============================================================================
// TESTS
// ============================================================================

test "Image: basic construction" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 100, 50, .RGBA);
    defer img.deinit();

    try std.testing.expectEqual(@as(u32, 100), img.width);
    try std.testing.expectEqual(@as(u32, 50), img.height);
    try std.testing.expectEqual(@as(u32, 400), img.stride); // 100 * 4
    try std.testing.expectEqual(PixelFormat.RGBA, img.format);
}

test "Image: pixel access" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 10, 10, .RGBA);
    defer img.deinit();

    // Set a pixel
    img.setPixel(5, 5, 255, 128, 64, 255);

    // Get the pixel
    const p = img.getPixel(5, 5);
    try std.testing.expect(p != null);
    try std.testing.expectEqual(@as(u8, 255), p.?.r);
    try std.testing.expectEqual(@as(u8, 128), p.?.g);
    try std.testing.expectEqual(@as(u8, 64), p.?.b);
    try std.testing.expectEqual(@as(u8, 255), p.?.a);
}

test "Image: BGRA format" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 10, 10, .BGRA);
    defer img.deinit();

    // Set a pixel (input is always RGBA, stored as BGRA)
    img.setPixel(0, 0, 255, 0, 0, 255); // Red

    // Check raw data is BGRA
    try std.testing.expectEqual(@as(u8, 0), img.data[0]); // B
    try std.testing.expectEqual(@as(u8, 0), img.data[1]); // G
    try std.testing.expectEqual(@as(u8, 255), img.data[2]); // R
    try std.testing.expectEqual(@as(u8, 255), img.data[3]); // A

    // Get pixel returns RGBA
    const p = img.getPixel(0, 0);
    try std.testing.expect(p != null);
    try std.testing.expectEqual(@as(u8, 255), p.?.r);
    try std.testing.expectEqual(@as(u8, 0), p.?.g);
    try std.testing.expectEqual(@as(u8, 0), p.?.b);
}

test "Image: convert BGRA to RGBA" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 1, 1, .BGRA);
    defer img.deinit();

    // Store as BGRA: B=10, G=20, R=30, A=255
    img.data[0] = 10;
    img.data[1] = 20;
    img.data[2] = 30;
    img.data[3] = 255;

    img.convertToRGBA();

    // After conversion: R=30, G=20, B=10, A=255
    try std.testing.expectEqual(@as(u8, 30), img.data[0]);
    try std.testing.expectEqual(@as(u8, 20), img.data[1]);
    try std.testing.expectEqual(@as(u8, 10), img.data[2]);
    try std.testing.expectEqual(@as(u8, 255), img.data[3]);
    try std.testing.expectEqual(PixelFormat.RGBA, img.format);
}

test "Image: out of bounds access" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 10, 10, .RGBA);
    defer img.deinit();

    // Out of bounds should return null
    try std.testing.expect(img.getPixel(100, 100) == null);
    try std.testing.expect(img.getPixel(10, 0) == null); // Edge
}

test "Image: getSubImage" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 100, 100, .RGBA);
    defer img.deinit();

    // Set a pixel in the region we'll extract
    img.setPixel(50, 50, 255, 0, 0, 255);

    // Extract sub-image
    var sub = try img.getSubImage(Rectangle.init(40, 40, 20, 20));
    defer sub.deinit();

    try std.testing.expectEqual(@as(u32, 20), sub.width);
    try std.testing.expectEqual(@as(u32, 20), sub.height);

    // The pixel at (50,50) in original should be at (10,10) in sub
    const p = sub.getPixel(10, 10);
    try std.testing.expect(p != null);
    try std.testing.expectEqual(@as(u8, 255), p.?.r);
}

test "Image: isPlainColor" {
    const allocator = std.testing.allocator;

    // Solid color image
    var solid = try Image.init(allocator, 10, 10, .RGBA);
    defer solid.deinit();
    // Already initialized to zeros - should be plain color
    try std.testing.expect(solid.isPlainColor());

    // Non-solid image
    var varied = try Image.init(allocator, 10, 10, .RGBA);
    defer varied.deinit();
    varied.setPixel(0, 0, 255, 0, 0, 255);
    varied.setPixel(5, 5, 0, 255, 0, 255);
    try std.testing.expect(!varied.isPlainColor());
}

test "Image: lastSeen optimization" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 10, 10, .RGBA);
    defer img.deinit();

    try std.testing.expect(img.last_seen == null);

    img.setLastSeen(Rectangle.init(100, 200, 50, 50));
    try std.testing.expect(img.last_seen != null);
    try std.testing.expectEqual(@as(i32, 100), img.last_seen.?.x);

    img.clearLastSeen();
    try std.testing.expect(img.last_seen == null);
}

test "bytesPerPixelForFormat" {
    try std.testing.expectEqual(@as(u32, 4), bytesPerPixelForFormat(.RGBA));
    try std.testing.expectEqual(@as(u32, 4), bytesPerPixelForFormat(.BGRA));
    try std.testing.expectEqual(@as(u32, 3), bytesPerPixelForFormat(.RGB));
    try std.testing.expectEqual(@as(u32, 3), bytesPerPixelForFormat(.BGR));
    try std.testing.expectEqual(@as(u32, 1), bytesPerPixelForFormat(.Grayscale));
}
