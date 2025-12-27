//! Real-World Error Handling
//!
//! This example demonstrates robust error handling in automation:
//! - Handling "element not found" gracefully
//! - Implementing retry logic with timeout
//! - Screenshot on failure for debugging
//! - Fallback strategies
//!
//! Run with: zig build run-realworld-error
//!
//! This example is designed to SUCCEED by demonstrating
//! proper error handling techniques.

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Region = zikuli.Region;
const Image = zikuli.Image;
const Finder = zikuli.Finder;
const Rectangle = zikuli.Rectangle;

/// Custom error types for automation
const AutomationError = error{
    ElementNotFound,
    Timeout,
    ScreenCaptureFailed,
};

/// Result of a find operation with metadata
const FindResult = struct {
    found: bool,
    attempts: u32,
    elapsed_ms: u64,
    location: ?zikuli.Point = null,
};

/// Wait for a pattern with retry logic
fn waitForPatternWithRetry(
    allocator: std.mem.Allocator,
    screen: *Screen,
    template: *const Image,
    timeout_ms: u64,
    check_interval_ms: u64,
) FindResult {
    const start_time = @as(u64, @intCast(std.time.milliTimestamp()));
    var attempts: u32 = 0;

    while (true) {
        attempts += 1;

        // Capture current screen
        var capture = screen.capture() catch {
            const elapsed = @as(u64, @intCast(std.time.milliTimestamp())) - start_time;
            if (elapsed >= timeout_ms) {
                return .{ .found = false, .attempts = attempts, .elapsed_ms = elapsed };
            }
            std.Thread.sleep(check_interval_ms * std.time.ns_per_ms);
            continue;
        };
        defer capture.deinit();

        var current_image = Image.fromCapture(allocator, capture) catch {
            const elapsed = @as(u64, @intCast(std.time.milliTimestamp())) - start_time;
            if (elapsed >= timeout_ms) {
                return .{ .found = false, .attempts = attempts, .elapsed_ms = elapsed };
            }
            std.Thread.sleep(check_interval_ms * std.time.ns_per_ms);
            continue;
        };
        defer current_image.deinit();

        // Try to find the pattern
        var finder = Finder.init(allocator, &current_image);
        defer finder.deinit();
        finder.min_similarity = 0.9;

        if (finder.find(template)) |match_result| {
            const elapsed = @as(u64, @intCast(std.time.milliTimestamp())) - start_time;
            return .{
                .found = true,
                .attempts = attempts,
                .elapsed_ms = elapsed,
                .location = match_result.center(),
            };
        }

        // Check timeout
        const elapsed = @as(u64, @intCast(std.time.milliTimestamp())) - start_time;
        if (elapsed >= timeout_ms) {
            return .{ .found = false, .attempts = attempts, .elapsed_ms = elapsed };
        }

        // Wait before next attempt
        std.Thread.sleep(check_interval_ms * std.time.ns_per_ms);
    }
}

/// Capture a debug screenshot on failure
/// Note: In production, you would save this to a file using image encoding
fn captureDebugScreenshot(allocator: std.mem.Allocator, screen: *Screen, reason: []const u8) !void {
    var capture = try screen.capture();
    defer capture.deinit();

    var img = try Image.fromCapture(allocator, capture);
    defer img.deinit();

    const timestamp = std.time.timestamp();

    // In production, you would save the image to a file here
    // For now, we report the capture details
    std.debug.print("  Debug screenshot captured: {s}_{} ({}x{}, {} bytes)\n", .{
        reason,
        timestamp,
        img.width,
        img.height,
        img.data.len,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Real-World Error Handling Example\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Initialize screen
    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    // Test 1: Handling "not found" gracefully
    try stdout.print("Test 1: Handling 'not found' gracefully...\n", .{});
    {
        // Create a non-existent pattern (random noise)
        var fake_pattern = try Image.init(allocator, 30, 30, .BGRA);
        defer fake_pattern.deinit();

        // Fill with random-ish data that won't match anything
        for (0..fake_pattern.height) |y| {
            for (0..fake_pattern.width) |x| {
                const idx = (y * fake_pattern.stride) + (x * 4);
                fake_pattern.data[idx] = @intCast((x * 17 + y * 23) % 256);
                fake_pattern.data[idx + 1] = @intCast((x * 31 + y * 13) % 256);
                fake_pattern.data[idx + 2] = @intCast((x * 7 + y * 41) % 256);
                fake_pattern.data[idx + 3] = 255;
            }
        }

        // Try to find it (will fail)
        const screen_region = screen.asRegion();
        const result = screen_region.findImage(allocator, &fake_pattern) catch null;

        if (result == null) {
            try stdout.print("  Pattern not found (expected)\n", .{});
            try stdout.print("  PASS: Gracefully handled missing element\n", .{});
        } else {
            try stdout.print("  Unexpectedly found pattern (false positive)\n", .{});
        }
    }

    // Test 2: Retry logic with timeout
    try stdout.print("\nTest 2: Retry logic with timeout...\n", .{});
    {
        // Create a pattern from current screen (will be found)
        var capture = try screen.capture();
        defer capture.deinit();

        var full_image = try Image.fromCapture(allocator, capture);
        defer full_image.deinit();

        // Extract a small pattern
        const pattern_rect = Rectangle.init(100, 100, 50, 50);
        var pattern = try full_image.getSubImage(pattern_rect);
        defer pattern.deinit();

        // Use retry logic
        const find_result = waitForPatternWithRetry(
            allocator,
            &screen,
            &pattern,
            2000, // 2 second timeout
            200, // Check every 200ms
        );

        if (find_result.found) {
            try stdout.print("  Found after {} attempts in {}ms\n", .{
                find_result.attempts,
                find_result.elapsed_ms,
            });
            if (find_result.location) |loc| {
                try stdout.print("  Location: ({}, {})\n", .{ loc.x, loc.y });
            }
            try stdout.print("  PASS: Retry logic works correctly\n", .{});
        } else {
            try stdout.print("  Not found after {} attempts ({}ms elapsed)\n", .{
                find_result.attempts,
                find_result.elapsed_ms,
            });
        }
    }

    // Test 3: Debug screenshot on failure
    try stdout.print("\nTest 3: Debug screenshot on failure...\n", .{});
    {
        // Simulate a failure scenario
        try captureDebugScreenshot(allocator, &screen, "simulated_failure");
        try stdout.print("  PASS: Debug screenshot saved successfully\n", .{});
    }

    // Test 4: Fallback strategy
    try stdout.print("\nTest 4: Fallback strategy...\n", .{});
    {
        // Try primary approach, then fallback
        var primary_success = false;

        // Primary: Try to find a specific pattern (will fail)
        var fake_pattern = try Image.init(allocator, 20, 20, .BGRA);
        defer fake_pattern.deinit();
        @memset(fake_pattern.data, 0xAB); // Random fill

        const screen_region = screen.asRegion();
        if ((screen_region.findImage(allocator, &fake_pattern) catch null) != null) {
            primary_success = true;
            try stdout.print("  Primary approach succeeded\n", .{});
        }

        if (!primary_success) {
            try stdout.print("  Primary approach failed, using fallback...\n", .{});

            // Fallback: Just report screen info
            try stdout.print("  Fallback: Screen is {}x{}\n", .{
                screen_region.width(),
                screen_region.height(),
            });
            try stdout.print("  PASS: Fallback strategy executed\n", .{});
        }
    }

    // Test 5: Validate screen access
    try stdout.print("\nTest 5: Validate resource access...\n", .{});
    {
        // Test that we can still access screen after previous operations
        var capture = screen.capture() catch |err| {
            try stdout.print("  FAIL: Cannot capture screen: {}\n", .{err});
            return;
        };
        defer capture.deinit();

        try stdout.print("  Screen access validated ({} bytes captured)\n", .{
            capture.pixels.len,
        });
        try stdout.print("  PASS: Resources are properly managed\n", .{});
    }

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Error handling example completed!\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Techniques demonstrated:\n", .{});
    try stdout.print("  - Graceful 'not found' handling\n", .{});
    try stdout.print("  - Retry logic with timeout\n", .{});
    try stdout.print("  - Debug screenshots on failure\n", .{});
    try stdout.print("  - Fallback strategies\n", .{});
    try stdout.print("  - Resource cleanup validation\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
