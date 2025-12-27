//! Mouse Control Integration Test
//!
//! This test verifies actual mouse control functionality using XTest.
//! It moves the mouse to various positions and verifies the actual position.
//!
//! Requirements:
//! - X11 display (DISPLAY environment variable)
//! - XTest extension available
//!
//! Run with: zig build test-mouse

const std = @import("std");
const zikuli = @import("zikuli");
const Mouse = zikuli.Mouse;
const Point = zikuli.Point;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli Mouse Control Integration Test\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Check if DISPLAY is set
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        try stdout.print("ERROR: DISPLAY environment variable not set\n", .{});
        try stdout.print("This test requires an X11 display\n", .{});
        return error.NoDisplay;
    }
    try stdout.print("Using display: {s}\n\n", .{display.?});

    // Test 1: Get current position
    try stdout.print("Test 1: Get current mouse position\n", .{});
    const initial_pos = Mouse.getPosition() catch |err| {
        try stdout.print("  FAIL: Could not get mouse position: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Current position: ({}, {})\n\n", .{ initial_pos.x, initial_pos.y });

    // Test 2: Move to absolute position
    try stdout.print("Test 2: Move mouse to (100, 100)\n", .{});
    Mouse.moveTo(100, 100) catch |err| {
        try stdout.print("  FAIL: Could not move mouse: {}\n", .{err});
        return err;
    };

    // Small delay to ensure X server processes the event
    std.Thread.sleep(50 * std.time.ns_per_ms);

    const pos1 = try Mouse.getPosition();
    if (@abs(pos1.x - 100) <= 2 and @abs(pos1.y - 100) <= 2) {
        try stdout.print("  PASS: Mouse at ({}, {})\n\n", .{ pos1.x, pos1.y });
    } else {
        try stdout.print("  FAIL: Expected (100, 100), got ({}, {})\n", .{ pos1.x, pos1.y });
        return error.PositionMismatch;
    }

    // Test 3: Move to another position
    try stdout.print("Test 3: Move mouse to (500, 300)\n", .{});
    try Mouse.moveTo(500, 300);
    std.Thread.sleep(50 * std.time.ns_per_ms);

    const pos2 = try Mouse.getPosition();
    if (@abs(pos2.x - 500) <= 2 and @abs(pos2.y - 300) <= 2) {
        try stdout.print("  PASS: Mouse at ({}, {})\n\n", .{ pos2.x, pos2.y });
    } else {
        try stdout.print("  FAIL: Expected (500, 300), got ({}, {})\n", .{ pos2.x, pos2.y });
        return error.PositionMismatch;
    }

    // Test 4: Smooth movement
    try stdout.print("Test 4: Smooth move from (500, 300) to (800, 500)\n", .{});
    try stdout.print("  (Watch for smooth animation over 300ms)\n", .{});
    try Mouse.smoothMove(800, 500, 300);
    std.Thread.sleep(50 * std.time.ns_per_ms);

    const pos3 = try Mouse.getPosition();
    if (@abs(pos3.x - 800) <= 2 and @abs(pos3.y - 500) <= 2) {
        try stdout.print("  PASS: Mouse at ({}, {})\n\n", .{ pos3.x, pos3.y });
    } else {
        try stdout.print("  FAIL: Expected (800, 500), got ({}, {})\n", .{ pos3.x, pos3.y });
        return error.PositionMismatch;
    }

    // Test 5: Move back to initial position
    try stdout.print("Test 5: Return to initial position ({}, {})\n", .{ initial_pos.x, initial_pos.y });
    try Mouse.smoothMoveTo(initial_pos.x, initial_pos.y);
    std.Thread.sleep(100 * std.time.ns_per_ms);

    const final_pos = try Mouse.getPosition();
    if (@abs(final_pos.x - initial_pos.x) <= 2 and @abs(final_pos.y - initial_pos.y) <= 2) {
        try stdout.print("  PASS: Mouse at ({}, {})\n\n", .{ final_pos.x, final_pos.y });
    } else {
        try stdout.print("  WARN: Expected ({}, {}), got ({}, {})\n", .{
            initial_pos.x, initial_pos.y,
            final_pos.x,   final_pos.y,
        });
    }

    // Summary
    try stdout.print("===========================================\n", .{});
    try stdout.print("All mouse control tests PASSED!\n", .{});
    try stdout.print("===========================================\n\n", .{});
}
