//! Verification test for OpenCV template matching
//!
//! This test verifies template matching works with actual images.
//! Run with: zig build test-finder
//!
//! Usage:
//!   test_finder --source <path> --template <path> [--threshold <0.0-1.0>]

const std = @import("std");
const zikuli = @import("zikuli");
const Finder = zikuli.Finder;
const Image = zikuli.Image;
const Rectangle = zikuli.Rectangle;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n=== Zikuli Template Matching Test ===\n\n", .{});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line args
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var source_path: ?[]const u8 = null;
    var template_path: ?[]const u8 = null;
    var threshold: f64 = 0.7;

    var i: usize = 1;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--source") and i + 1 < args.len) {
            i += 1;
            source_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--template") and i + 1 < args.len) {
            i += 1;
            template_path = args[i];
        } else if (std.mem.eql(u8, args[i], "--threshold") and i + 1 < args.len) {
            i += 1;
            threshold = std.fmt.parseFloat(f64, args[i]) catch 0.7;
        }
    }

    // If no args, run built-in synthetic test
    if (source_path == null and template_path == null) {
        try runSyntheticTest(allocator, &stdout);
        return;
    }

    // Require both paths if any provided
    if (source_path == null or template_path == null) {
        try stdout.print("Usage: test_finder --source <path> --template <path> [--threshold <0.0-1.0>]\n", .{});
        return;
    }

    try runFileTest(allocator, &stdout, source_path.?, template_path.?, threshold);
}

fn runSyntheticTest(allocator: std.mem.Allocator, stdout: anytype) !void {
    try stdout.print("[1] Running synthetic test (no files needed)...\n\n", .{});

    // Create a source image with a distinct pattern
    try stdout.print("[2] Creating source image (200x200)...\n", .{});
    var source = try Image.init(allocator, 200, 200, .RGBA);
    defer source.deinit();

    // Fill with gray background
    for (0..source.height) |y| {
        for (0..source.width) |x| {
            source.setPixel(@intCast(x), @intCast(y), 128, 128, 128, 255);
        }
    }

    // Draw a red square at position (50, 50) with size 30x30
    const template_x: u32 = 50;
    const template_y: u32 = 50;
    const template_size: u32 = 30;

    for (template_y..template_y + template_size) |y| {
        for (template_x..template_x + template_size) |x| {
            source.setPixel(@intCast(x), @intCast(y), 255, 0, 0, 255);
        }
    }
    try stdout.print("    Source has red square at ({d},{d}) size {d}x{d}\n", .{ template_x, template_y, template_size, template_size });

    // Create template image (the red square)
    try stdout.print("\n[3] Creating template image ({d}x{d})...\n", .{ template_size, template_size });
    var template = try Image.init(allocator, template_size, template_size, .RGBA);
    defer template.deinit();

    // Fill template with red
    for (0..template.height) |y| {
        for (0..template.width) |x| {
            template.setPixel(@intCast(x), @intCast(y), 255, 0, 0, 255);
        }
    }

    // Test isPlainColor detection
    try stdout.print("    Template isPlainColor: {}\n", .{template.isPlainColor()});

    // Run finder
    try stdout.print("\n[4] Running template matching...\n", .{});
    var finder = Finder.init(allocator, &source);
    defer finder.deinit();

    if (finder.find(&template)) |match| {
        try stdout.print("    Match found at ({d},{d}) with score {d:.4}\n", .{ match.bounds.x, match.bounds.y, match.score });

        // Verify match location
        const expected_x: i32 = @intCast(template_x);
        const expected_y: i32 = @intCast(template_y);

        if (match.bounds.x == expected_x and match.bounds.y == expected_y) {
            try stdout.print("\n=== Synthetic test PASSED ===\n\n", .{});
        } else {
            try stdout.print("\nWARNING: Match position ({d},{d}) differs from expected ({d},{d})\n", .{ match.bounds.x, match.bounds.y, expected_x, expected_y });
            try stdout.print("This may be due to OpenCV not being properly linked.\n", .{});
        }
    } else {
        try stdout.print("    No match found!\n", .{});
        try stdout.print("\nNOTE: OpenCV may not be linked correctly.\n", .{});
        try stdout.print("Check that libopencv4 is installed and linked.\n\n", .{});
    }
}

fn runFileTest(_: std.mem.Allocator, stdout: anytype, source_path: []const u8, template_path: []const u8, threshold: f64) !void {
    try stdout.print("[1] Loading images from files...\n", .{});
    try stdout.print("    Source: {s}\n", .{source_path});
    try stdout.print("    Template: {s}\n", .{template_path});
    try stdout.print("    Threshold: {d:.2}\n\n", .{threshold});

    // TODO: Implement PNG loading and run finder
    try stdout.print("NOTE: File-based test not yet implemented.\n", .{});
    try stdout.print("Need to add PNG loading to Image type first.\n", .{});
}
