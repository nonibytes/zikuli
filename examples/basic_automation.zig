//! Basic Automation Example
//!
//! This example demonstrates the core Zikuli functionality:
//! - Getting the primary screen
//! - Capturing screenshots
//! - Working with regions
//! - Mouse and keyboard operations
//!
//! Run with: zig build run-example-basic

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Region = zikuli.Region;
const Mouse = zikuli.Mouse;
const Keyboard = zikuli.Keyboard;
const Image = zikuli.Image;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli Basic Automation Example\n", .{});
    try stdout.print("Version: {s}\n", .{zikuli.getVersion()});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Step 1: Get the primary screen
    try stdout.print("Step 1: Getting primary screen...\n", .{});
    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("  Screen size: {}x{}\n", .{ screen_region.width(), screen_region.height() });

    // Step 2: Capture a screenshot
    try stdout.print("\nStep 2: Capturing screenshot...\n", .{});
    var capture = try screen.capture();
    defer capture.deinit();

    // Convert to Image
    var img = try Image.fromCapture(allocator, capture);
    defer img.deinit();
    try stdout.print("  Captured {}x{} pixels\n", .{ img.width, img.height });

    // Step 3: Get mouse position
    try stdout.print("\nStep 3: Getting mouse position...\n", .{});
    const mouse_pos = Mouse.getPosition() catch |err| {
        try stdout.print("  Warning: Could not get mouse position: {}\n", .{err});
        return;
    };
    try stdout.print("  Mouse at: ({}, {})\n", .{ mouse_pos.x, mouse_pos.y });

    // Step 4: Create a sub-region
    try stdout.print("\nStep 4: Working with sub-regions...\n", .{});
    const top_left = Region.initAt(0, 0, 200, 200);
    const center = screen_region.center();
    try stdout.print("  Top-left region: (0, 0) to (200, 200)\n", .{});
    try stdout.print("  Screen center: ({}, {})\n", .{ center.x, center.y });

    // Step 5: Demonstrate region operations
    try stdout.print("\nStep 5: Region manipulation...\n", .{});

    // Offset
    const offset_region = top_left.offset(50, 50);
    try stdout.print("  Offset by (50,50): ({}, {})\n", .{ offset_region.x(), offset_region.y() });

    // Grow/shrink
    const grown = top_left.grow(10);
    try stdout.print("  Grown by 10: {}x{}\n", .{ grown.width(), grown.height() });

    // Directional regions (using Sikuli-style API)
    const right_region = top_left.rightOf(100); // Region 100 pixels to the right
    try stdout.print("  Right of top_left: x={}, width={}\n", .{ right_region.x(), right_region.width() });

    const below_region = top_left.below(100); // Region 100 pixels below
    try stdout.print("  Below top_left: y={}, height={}\n", .{ below_region.y(), below_region.height() });

    // Step 6: Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Basic automation example completed!\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
