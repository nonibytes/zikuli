//! Real-World Screenshot Automation
//!
//! This example demonstrates practical screen capture automation:
//! - Capture full screen
//! - Capture specific regions
//! - Analyze captured images
//! - Perform OCR on captured regions
//!
//! Run with: zig build run-realworld-screenshot
//!
//! This is a non-interactive example that demonstrates
//! Zikuli's capture and analysis capabilities.

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Region = zikuli.Region;
const Image = zikuli.Image;
const Rectangle = zikuli.Rectangle;
const OCR = zikuli.OCR;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Real-World Screenshot Automation\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Step 1: Initialize screen
    try stdout.print("Step 1: Initializing screen...\n", .{});
    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("  Screen: {}x{} pixels\n", .{ screen_region.width(), screen_region.height() });

    // Step 2: Capture full screen
    try stdout.print("\nStep 2: Capturing full screen...\n", .{});
    var capture = try screen.capture();
    defer capture.deinit();

    var full_image = try Image.fromCapture(allocator, capture);
    defer full_image.deinit();
    try stdout.print("  Captured: {}x{} pixels ({} bytes)\n", .{
        full_image.width,
        full_image.height,
        full_image.data.len,
    });

    // Step 3: Capture specific regions
    try stdout.print("\nStep 3: Capturing specific regions...\n", .{});

    // Top-left quadrant
    const top_left_rect = Rectangle.init(0, 0, screen_region.width() / 2, screen_region.height() / 2);
    var top_left_img = try full_image.getSubImage(top_left_rect);
    defer top_left_img.deinit();
    try stdout.print("  Top-left quadrant: {}x{} pixels\n", .{ top_left_img.width, top_left_img.height });

    // Center region
    const center_x = screen_region.width() / 2 - 200;
    const center_y = screen_region.height() / 2 - 150;
    const center_rect = Rectangle.init(@intCast(center_x), @intCast(center_y), 400, 300);
    var center_img = try full_image.getSubImage(center_rect);
    defer center_img.deinit();
    try stdout.print("  Center region: {}x{} pixels\n", .{ center_img.width, center_img.height });

    // Step 4: Perform OCR on regions
    try stdout.print("\nStep 4: Performing OCR analysis...\n", .{});
    var ocr = try OCR.init(allocator);
    defer ocr.deinit();

    // OCR on top bar (likely contains window titles)
    const top_bar_rect = Rectangle.init(0, 0, screen_region.width(), 60);
    var top_bar_img = try full_image.getSubImage(top_bar_rect);
    defer top_bar_img.deinit();

    ocr.setPageSegMode(.single_line);
    const top_bar_text = try ocr.readText(&top_bar_img);
    defer allocator.free(top_bar_text);

    if (top_bar_text.len > 0) {
        const preview_len = @min(top_bar_text.len, 80);
        try stdout.print("  Top bar text: \"{s}...\"\n", .{top_bar_text[0..preview_len]});
    } else {
        try stdout.print("  Top bar: (no text detected)\n", .{});
    }

    // OCR word count on full screen
    ocr.setPageSegMode(.auto);
    const words = try ocr.readWords(&full_image);
    defer {
        for (words) |word| {
            allocator.free(word.text);
        }
        allocator.free(words);
    }
    try stdout.print("  Total words on screen: {}\n", .{words.len});

    // Step 5: Analyze screen content
    try stdout.print("\nStep 5: Screen analysis summary...\n", .{});

    // Count words with high confidence
    var high_conf_count: usize = 0;
    for (words) |word| {
        if (word.confidence > 80.0) {
            high_conf_count += 1;
        }
    }
    try stdout.print("  High confidence words (>80%%): {}\n", .{high_conf_count});

    // Report memory usage
    const total_bytes = full_image.data.len + top_left_img.data.len + center_img.data.len + top_bar_img.data.len;
    try stdout.print("  Total image data processed: {} KB\n", .{total_bytes / 1024});

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Screenshot automation completed!\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("What was demonstrated:\n", .{});
    try stdout.print("  - Full screen capture\n", .{});
    try stdout.print("  - Multi-region extraction\n", .{});
    try stdout.print("  - OCR text extraction and analysis\n", .{});
    try stdout.print("  - Memory-efficient image processing\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
