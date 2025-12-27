//! Find and Click Example
//!
//! This example demonstrates Zikuli's core visual automation:
//! - Capturing the screen
//! - Finding an image pattern (template matching)
//! - Clicking on the found match
//!
//! Run with: zig build run-example-find
//!
//! Usage:
//!   This example extracts a pattern from the screen center,
//!   then finds it and clicks on it. In real usage, you would
//!   load a template image from a file.

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Region = zikuli.Region;
const Mouse = zikuli.Mouse;
const Image = zikuli.Image;
const Finder = zikuli.Finder;
const Rectangle = zikuli.Rectangle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli Find and Click Example\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Step 1: Get the primary screen
    try stdout.print("Step 1: Getting primary screen...\n", .{});
    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("  Screen: {}x{}\n", .{ screen_region.width(), screen_region.height() });

    // Step 2: Capture the screen
    try stdout.print("\nStep 2: Capturing screen...\n", .{});
    var capture = try screen.capture();
    defer capture.deinit();

    var full_image = try Image.fromCapture(allocator, capture);
    defer full_image.deinit();
    try stdout.print("  Captured {}x{} pixels\n", .{ full_image.width, full_image.height });

    // Step 3: Extract a template pattern from the center of the screen
    // In real usage, you would load this from a file like:
    //   var template = try Image.fromFile(allocator, "button.png");
    try stdout.print("\nStep 3: Creating template pattern...\n", .{});

    const center_x: u32 = full_image.width / 2;
    const center_y: u32 = full_image.height / 2;
    const pattern_size: u32 = 80;

    const pattern_rect = Rectangle.init(
        @intCast(center_x - pattern_size / 2),
        @intCast(center_y - pattern_size / 2),
        pattern_size,
        pattern_size,
    );

    var template = try full_image.getSubImage(pattern_rect);
    defer template.deinit();
    try stdout.print("  Template: {}x{} pixels from screen center\n", .{ template.width, template.height });

    // Step 4: Find the template on screen
    try stdout.print("\nStep 4: Finding template on screen...\n", .{});

    var finder = Finder.init(allocator, &full_image);
    defer finder.deinit();

    finder.min_similarity = 0.9; // High threshold since we're finding exact match

    if (finder.find(&template)) |match_result| {
        try stdout.print("  FOUND at ({}, {}) with score {d:.3}\n", .{
            match_result.bounds.x,
            match_result.bounds.y,
            match_result.score,
        });

        // Step 5: Click on the match
        try stdout.print("\nStep 5: Clicking on match...\n", .{});
        const click_point = match_result.center();
        try stdout.print("  Clicking at ({}, {})\n", .{ click_point.x, click_point.y });

        // Move mouse smoothly to target
        try Mouse.smoothMoveTo(click_point.x, click_point.y);
        std.Thread.sleep(100 * std.time.ns_per_ms);

        // Click
        try Mouse.click(.left);
        try stdout.print("  Click completed!\n", .{});
    } else {
        try stdout.print("  Pattern not found on screen\n", .{});
    }

    // Step 6: Using Region's find method (integrated capture + find)
    try stdout.print("\nStep 6: Using Region.findImage()...\n", .{});

    // Recapture fresh screen
    var capture2 = try screen.capture();
    defer capture2.deinit();
    var fresh_image = try Image.fromCapture(allocator, capture2);
    defer fresh_image.deinit();

    // Extract new template
    var template2 = try fresh_image.getSubImage(pattern_rect);
    defer template2.deinit();

    // Use Region's integrated findImage
    if (try screen_region.findImage(allocator, &template2)) |region_match| {
        try stdout.print("  Region.findImage() found at ({}, {})\n", .{
            region_match.bounds.x,
            region_match.bounds.y,
        });
    } else {
        try stdout.print("  Region.findImage() did not find pattern\n", .{});
    }

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Find and click example completed!\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
