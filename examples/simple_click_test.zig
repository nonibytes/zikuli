//! Simple Click Test - Proves mouse clicking works
//!
//! This test moves the mouse to visible locations and clicks.
//! You can watch the mouse cursor move on screen.

const std = @import("std");
const zikuli = @import("zikuli");

const Mouse = zikuli.Mouse;
const Screen = zikuli.Screen;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n=== SIMPLE MOUSE CLICK TEST ===\n\n", .{});
    try stdout.print("Watch your mouse cursor - it will move and click!\n\n", .{});

    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    const region = screen.asRegion();
    try stdout.print("Screen size: {}x{}\n\n", .{ region.width(), region.height() });

    // Move to center of screen
    const center_x: i32 = @intCast(region.width() / 2);
    const center_y: i32 = @intCast(region.height() / 2);

    try stdout.print("Step 1: Moving mouse to CENTER ({}, {})...\n", .{ center_x, center_y });
    try Mouse.moveTo(center_x, center_y);
    std.Thread.sleep(1 * std.time.ns_per_s);

    // Get current position to verify
    const pos1 = try Mouse.getPosition();
    try stdout.print("  Current position: ({}, {})\n", .{ pos1.x, pos1.y });

    // Move to top-left
    try stdout.print("\nStep 2: Moving mouse to TOP-LEFT (100, 100)...\n", .{});
    try Mouse.moveTo(100, 100);
    std.Thread.sleep(1 * std.time.ns_per_s);

    const pos2 = try Mouse.getPosition();
    try stdout.print("  Current position: ({}, {})\n", .{ pos2.x, pos2.y });

    // Move to bottom-right
    const br_x: i32 = @intCast(region.width() - 100);
    const br_y: i32 = @intCast(region.height() - 100);
    try stdout.print("\nStep 3: Moving mouse to BOTTOM-RIGHT ({}, {})...\n", .{ br_x, br_y });
    try Mouse.moveTo(br_x, br_y);
    std.Thread.sleep(1 * std.time.ns_per_s);

    const pos3 = try Mouse.getPosition();
    try stdout.print("  Current position: ({}, {})\n", .{ pos3.x, pos3.y });

    // Now click test
    try stdout.print("\nStep 4: Moving back to center and CLICKING...\n", .{});
    try Mouse.moveTo(center_x, center_y);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    try stdout.print("  CLICKING NOW!\n", .{});
    try Mouse.click(.left);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    try stdout.print("\nStep 5: Double-click test...\n", .{});
    try Mouse.doubleClick(.left);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    try stdout.print("\n=== TEST COMPLETE ===\n", .{});
    try stdout.print("Did you see the mouse cursor move around the screen?\n", .{});
    try stdout.print("If yes, Zikuli mouse control is working!\n\n", .{});
}
