//! Verification test for X11 screen capture
//!
//! This test actually captures a screenshot and verifies it works.
//! Run with: zig build test-capture

const std = @import("std");
const zikuli = @import("zikuli");
const X11Connection = zikuli.x11.X11Connection;
const Rectangle = zikuli.Rectangle;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n=== Zikuli X11 Screen Capture Test ===\n\n", .{});

    // Connect to X11
    try stdout.print("[1] Connecting to X11...\n", .{});
    var conn = X11Connection.connectDefault() catch |err| {
        try stdout.print("ERROR: Failed to connect to X11: {}\n", .{err});
        try stdout.print("Make sure you're running in an X11 session.\n", .{});
        return err;
    };
    defer conn.disconnect();

    try stdout.print("    Connected! Screen: {d}x{d}, Depth: {d} bits\n", .{
        conn.getScreenWidth(),
        conn.getScreenHeight(),
        conn.getDepth(),
    });

    // Capture a small region (100x100 from top-left)
    try stdout.print("\n[2] Capturing 100x100 region from (0,0)...\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var img = conn.captureRegion(allocator, Rectangle.init(0, 0, 100, 100)) catch |err| {
        try stdout.print("ERROR: Failed to capture: {}\n", .{err});
        return err;
    };
    defer img.deinit();

    try stdout.print("    Captured! Size: {d}x{d}, {d} bytes\n", .{
        img.width,
        img.height,
        img.size(),
    });

    // Sample some pixels
    try stdout.print("\n[3] Sampling pixels...\n", .{});

    if (img.getPixel(0, 0)) |p| {
        try stdout.print("    Pixel (0,0): R={d} G={d} B={d} A={d}\n", .{ p.r, p.g, p.b, p.a });
    }

    if (img.getPixel(50, 50)) |p| {
        try stdout.print("    Pixel (50,50): R={d} G={d} B={d} A={d}\n", .{ p.r, p.g, p.b, p.a });
    }

    if (img.getPixel(99, 99)) |p| {
        try stdout.print("    Pixel (99,99): R={d} G={d} B={d} A={d}\n", .{ p.r, p.g, p.b, p.a });
    }

    // Test BGRA to RGBA conversion
    try stdout.print("\n[4] Testing BGRA->RGBA conversion...\n", .{});
    img.convertToRGBA();
    try stdout.print("    Format now: {}\n", .{img.format});

    // Full screen capture
    try stdout.print("\n[5] Capturing full screen...\n", .{});
    var full_img = conn.captureFullScreen(allocator) catch |err| {
        try stdout.print("ERROR: Failed to capture full screen: {}\n", .{err});
        return err;
    };
    defer full_img.deinit();

    try stdout.print("    Full screen: {d}x{d}, {d} bytes ({d:.2} MB)\n", .{
        full_img.width,
        full_img.height,
        full_img.size(),
        @as(f64, @floatFromInt(full_img.size())) / (1024.0 * 1024.0),
    });

    try stdout.print("\n=== All tests PASSED ===\n\n", .{});
}
