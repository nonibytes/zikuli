//! Region Operations Integration Test
//!
//! This test verifies the integrated Region operations:
//! - Region.find(pattern) - capture + template match
//! - Region.click(pattern) - find + click
//! - Region.wait(pattern, timeout) - loop until found or timeout
//! - Region.exists(pattern) - check if pattern exists
//!
//! Requirements:
//! - X11 display (DISPLAY environment variable)
//! - XTest extension available
//!
//! Run with: zig build test-region-ops

const std = @import("std");
const zikuli = @import("zikuli");
const Region = zikuli.Region;
const Screen = zikuli.Screen;
const Pattern = zikuli.Pattern;
const Match = zikuli.Match;
const Image = zikuli.Image;
const Rectangle = zikuli.Rectangle;
const Finder = zikuli.Finder;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli Region Operations Integration Test\n", .{});
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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test 1: Create a screen region and capture
    try stdout.print("Test 1: Create screen region and capture\n", .{});
    var screen = Screen.primary(allocator) catch |err| {
        try stdout.print("  FAIL: Could not get primary screen: {}\n", .{err});
        return err;
    };
    defer screen.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("  Screen region: {}x{}\n", .{ screen_region.width(), screen_region.height() });

    // Capture the screen
    var capture = screen.capture() catch |err| {
        try stdout.print("  FAIL: Could not capture screen: {}\n", .{err});
        return err;
    };
    defer capture.deinit();
    try stdout.print("  PASS: Screen captured ({}x{} pixels)\n\n", .{ capture.width, capture.height });

    // Test 2: Create test pattern from captured image
    try stdout.print("Test 2: Create test pattern from screen region\n", .{});

    // Create Image from capture
    var full_image = Image.fromCapture(allocator, capture) catch |err| {
        try stdout.print("  FAIL: Could not create image from capture: {}\n", .{err});
        return err;
    };
    defer full_image.deinit();

    // Extract a 50x50 pixel region from center of screen as our "pattern"
    const center_x: u32 = capture.width / 2;
    const center_y: u32 = capture.height / 2;
    const pattern_size: u32 = 50;

    const pattern_rect = Rectangle.init(
        @intCast(center_x - pattern_size / 2),
        @intCast(center_y - pattern_size / 2),
        pattern_size,
        pattern_size,
    );

    var pattern_image = full_image.getSubImage(pattern_rect) catch |err| {
        try stdout.print("  FAIL: Could not extract sub-image: {}\n", .{err});
        return err;
    };
    defer pattern_image.deinit();
    try stdout.print("  PASS: Pattern created ({}x{} pixels)\n\n", .{ pattern_image.width, pattern_image.height });

    // Test 3: Use Finder directly to verify template matching works
    try stdout.print("Test 3: Finder.find() - verify template matching\n", .{});
    var finder = Finder.init(allocator, &full_image);
    defer finder.deinit();

    const finder_result = finder.find(&pattern_image);
    if (finder_result) |match_result| {
        try stdout.print("  PASS: Template found at ({}, {}) with score {d:.3}\n", .{
            match_result.bounds.x,
            match_result.bounds.y,
            match_result.score,
        });

        // Verify the match location is near where we extracted the pattern
        const expected_x: i32 = @intCast(center_x - pattern_size / 2);
        const expected_y: i32 = @intCast(center_y - pattern_size / 2);
        const tolerance: i32 = 5;

        if (@abs(match_result.bounds.x - expected_x) > tolerance or
            @abs(match_result.bounds.y - expected_y) > tolerance)
        {
            try stdout.print("  WARNING: Match location differs from expected by more than {} pixels\n", .{tolerance});
            try stdout.print("           Expected: ({}, {}), Got: ({}, {})\n", .{
                expected_x,
                expected_y,
                match_result.bounds.x,
                match_result.bounds.y,
            });
        }
    } else {
        try stdout.print("  FAIL: Template not found (should have found it at screen center)\n", .{});
        return error.PatternNotFound;
    }
    try stdout.print("\n", .{});

    // Test 4: Region.find() - the integrated operation
    // THIS IS THE KEY TEST - Region.find() should combine capture + find
    try stdout.print("Test 4: Region.find() - integrated find operation\n", .{});

    // Create pattern from file path (for now we'll test with a dummy path)
    // In actual usage, the pattern would load from a file
    // For this test, we need Region.findImage() which takes an Image directly
    const find_result = screen_region.findImage(allocator, &pattern_image) catch |err| {
        try stdout.print("  FAIL: Region.findImage() failed: {}\n", .{err});
        return err;
    };

    if (find_result) |match_result| {
        try stdout.print("  PASS: Pattern found via Region.findImage() at ({}, {})\n\n", .{
            match_result.bounds.x,
            match_result.bounds.y,
        });
    } else {
        try stdout.print("  FAIL: Pattern not found via Region.findImage()\n", .{});
        return error.RegionFindFailed;
    }

    // Test 5: Region.exists() - check if pattern exists
    try stdout.print("Test 5: Region.existsImage() - check if pattern exists\n", .{});
    const exists = screen_region.existsImage(allocator, &pattern_image, 0.5) catch |err| {
        try stdout.print("  FAIL: Region.existsImage() failed: {}\n", .{err});
        return err;
    };

    if (exists) {
        try stdout.print("  PASS: Pattern exists in region\n\n", .{});
    } else {
        try stdout.print("  FAIL: Pattern should exist but wasn't found\n", .{});
        return error.PatternShouldExist;
    }

    // Test 6: Region.waitImage() - wait for pattern (should find immediately)
    try stdout.print("Test 6: Region.waitImage() - wait for pattern (should find immediately)\n", .{});
    const wait_result = screen_region.waitImage(allocator, &pattern_image, 2.0) catch |err| {
        try stdout.print("  FAIL: Region.waitImage() failed: {}\n", .{err});
        return err;
    };

    if (wait_result) |match_result| {
        try stdout.print("  PASS: Pattern found via waitImage() at ({}, {})\n\n", .{
            match_result.bounds.x,
            match_result.bounds.y,
        });
    } else {
        try stdout.print("  FAIL: waitImage() should have found the pattern\n", .{});
        return error.WaitFailed;
    }

    // Test 7: Region.clickImage() - find and click on pattern
    try stdout.print("Test 7: Region.clickImage() - find and click on pattern\n", .{});
    screen_region.clickImage(allocator, &pattern_image) catch |err| {
        try stdout.print("  FAIL: Region.clickImage() failed: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Pattern clicked\n\n", .{});

    // Test 8: Sub-region find
    try stdout.print("Test 8: Sub-region findImage() - search in constrained area\n", .{});
    const sub_region = Region.initAt(
        @intCast(center_x - 100),
        @intCast(center_y - 100),
        200,
        200,
    );

    const sub_find_result = sub_region.findImage(allocator, &pattern_image) catch |err| {
        try stdout.print("  FAIL: Sub-region findImage() failed: {}\n", .{err});
        return err;
    };

    if (sub_find_result) |_| {
        try stdout.print("  PASS: Pattern found in sub-region\n\n", .{});
    } else {
        try stdout.print("  FAIL: Pattern not found in sub-region\n", .{});
        return error.SubRegionFindFailed;
    }

    // Test 9: waitVanishImage() - pattern should NOT vanish (screen is static)
    try stdout.print("Test 9: Region.waitVanishImage() - pattern should not vanish\n", .{});
    const vanished = screen_region.waitVanishImage(allocator, &pattern_image, 0.5) catch |err| {
        try stdout.print("  FAIL: Region.waitVanishImage() failed: {}\n", .{err});
        return err;
    };

    if (!vanished) {
        try stdout.print("  PASS: Pattern correctly did not vanish (screen is static)\n\n", .{});
    } else {
        try stdout.print("  FAIL: Pattern incorrectly reported as vanished\n", .{});
        return error.WaitVanishFailed;
    }

    // Test 10: Region.doubleClickImage()
    try stdout.print("Test 10: Region.doubleClickImage() - double-click on pattern\n", .{});
    screen_region.doubleClickImage(allocator, &pattern_image) catch |err| {
        try stdout.print("  FAIL: Region.doubleClickImage() failed: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Pattern double-clicked\n\n", .{});

    // Test 11: Region.rightClickImage()
    try stdout.print("Test 11: Region.rightClickImage() - right-click on pattern\n", .{});
    screen_region.rightClickImage(allocator, &pattern_image) catch |err| {
        try stdout.print("  FAIL: Region.rightClickImage() failed: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Pattern right-clicked\n\n", .{});

    // Summary
    try stdout.print("===========================================\n", .{});
    try stdout.print("All Region operations tests PASSED!\n", .{});
    try stdout.print("===========================================\n\n", .{});
}
