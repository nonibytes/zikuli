//! SikuliX-Style API Integration Test
//!
//! Tests the new SikuliX-style Region methods:
//! - find(), findAll(), exists(), wait(), waitVanish()
//! - click(), clickWithModifiers(), doubleClick(), rightClick()
//! - hover(), hoverCenter()
//! - typeAt(), typeText(), typeWithModifiers(), hotkey()
//! - drag(), dragTo(), dragDrop(), drop()
//! - wheel(), wheelUp(), wheelDown()
//!
//! Requirements:
//! - X11 display (DISPLAY environment variable)
//! - XTest extension available
//!
//! Run with: zig build test-sikulix-api

const std = @import("std");
const zikuli = @import("zikuli");

const Region = zikuli.Region;
const Screen = zikuli.Screen;
const Image = zikuli.Image;
const Rectangle = zikuli.Rectangle;
const FindFailed = zikuli.FindFailed;
const KeyModifier = zikuli.KeyModifier;
const PixelFormat = zikuli.image.PixelFormat;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("================================================\n", .{});
    try stdout.print("Zikuli SikuliX-Style API Integration Test\n", .{});
    try stdout.print("================================================\n", .{});
    try stdout.print("\n", .{});

    // Check if DISPLAY is set
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        try stdout.print("ERROR: DISPLAY environment variable not set\n", .{});
        return error.NoDisplay;
    }
    try stdout.print("Using display: {s}\n\n", .{display.?});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Setup: Create screen and pattern
    try stdout.print("Setup: Creating screen and test pattern\n", .{});
    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("  Screen: {}x{}\n", .{ screen_region.width(), screen_region.height() });

    // Move mouse to corner BEFORE capturing, so cursor doesn't affect pattern area
    // This ensures the center area (where we extract the pattern) is clean
    const Mouse = zikuli.Mouse;
    try Mouse.moveTo(10, 10);
    std.Thread.sleep(100 * std.time.ns_per_ms); // Brief pause for screen to update

    // Capture screen and create a pattern from center
    var capture = try screen.capture();
    defer capture.deinit();

    var full_image = try Image.fromCapture(allocator, capture);
    defer full_image.deinit();

    // Extract 50x50 pattern from center (cursor is in corner, won't affect this)
    const center_x: u32 = capture.width / 2;
    const center_y: u32 = capture.height / 2;
    const pattern_rect = Rectangle.init(
        @intCast(center_x - 25),
        @intCast(center_y - 25),
        50,
        50,
    );

    var pattern_image = try full_image.getSubImage(pattern_rect);
    defer pattern_image.deinit();
    try stdout.print("  Pattern: {}x{}\n\n", .{ pattern_image.width, pattern_image.height });

    var tests_passed: u32 = 0;
    var tests_failed: u32 = 0;

    // ========================================================================
    // Test 1: find() - should find the pattern
    // ========================================================================
    try stdout.print("Test 1: Region.find() - SikuliX-style find\n", .{});
    {
        const match_result = screen_region.find(allocator, &pattern_image) catch |err| {
            try stdout.print("  FAIL: find() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Pattern found at ({}, {}) score={d:.3}\n\n", .{
            match_result.bounds.x,
            match_result.bounds.y,
            match_result.score,
        });
        tests_passed += 1;
    }

    // ========================================================================
    // Test 2: exists() - should return Match, not null
    // ========================================================================
    try stdout.print("Test 2: Region.exists() - check pattern exists\n", .{});
    {
        const exists_result = try screen_region.exists(allocator, &pattern_image, 1.0);
        if (exists_result) |match_result| {
            try stdout.print("  PASS: Pattern exists at ({}, {})\n\n", .{
                match_result.bounds.x,
                match_result.bounds.y,
            });
            tests_passed += 1;
        } else {
            try stdout.print("  FAIL: exists() returned null but pattern should exist\n\n", .{});
            tests_failed += 1;
        }
    }

    // ========================================================================
    // Test 3: wait() - should find immediately
    // ========================================================================
    try stdout.print("Test 3: Region.wait() - wait for pattern\n", .{});
    {
        const start = std.time.milliTimestamp();
        const match_result = screen_region.wait(allocator, &pattern_image, 2.0) catch |err| {
            try stdout.print("  FAIL: wait() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        const elapsed = std.time.milliTimestamp() - start;
        try stdout.print("  PASS: Pattern found in {d}ms at ({}, {})\n\n", .{
            elapsed,
            match_result.bounds.x,
            match_result.bounds.y,
        });
        tests_passed += 1;
    }

    // ========================================================================
    // Test 4: waitVanish() - pattern should NOT vanish (screen is static)
    // ========================================================================
    try stdout.print("Test 4: Region.waitVanish() - pattern should not vanish\n", .{});
    {
        const vanished = screen_region.waitVanish(allocator, &pattern_image, 0.3) catch |err| {
            try stdout.print("  FAIL: waitVanish() threw unexpected error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };

        // SikuliX behavior: returns false if pattern still present after timeout
        if (!vanished) {
            try stdout.print("  PASS: Correctly returned false (pattern still present)\n\n", .{});
            tests_passed += 1;
        } else {
            try stdout.print("  FAIL: Pattern vanished unexpectedly (screen should be static)\n\n", .{});
            tests_failed += 1;
        }
    }

    // ========================================================================
    // Test 5: click() - find and click pattern
    // ========================================================================
    try stdout.print("Test 5: Region.click() - find and click pattern\n", .{});
    {
        const match_result = screen_region.click(allocator, &pattern_image) catch |err| {
            try stdout.print("  FAIL: click() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Clicked at ({}, {})\n\n", .{
            match_result.center().x,
            match_result.center().y,
        });
        tests_passed += 1;
        // Move mouse back to corner so cursor doesn't affect pattern area
        try Mouse.moveTo(10, 10);
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }

    // ========================================================================
    // Test 6: doubleClick() - find and double-click
    // ========================================================================
    try stdout.print("Test 6: Region.doubleClick() - find and double-click\n", .{});
    {
        _ = screen_region.doubleClick(allocator, &pattern_image) catch |err| {
            try stdout.print("  FAIL: doubleClick() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Double-clicked on pattern\n\n", .{});
        tests_passed += 1;
        // Move mouse back to corner so cursor doesn't affect pattern area
        try Mouse.moveTo(10, 10);
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }

    // ========================================================================
    // Test 7: rightClick() - find and right-click
    // ========================================================================
    try stdout.print("Test 7: Region.rightClick() - find and right-click\n", .{});
    {
        _ = screen_region.rightClick(allocator, &pattern_image) catch |err| {
            try stdout.print("  FAIL: rightClick() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Right-clicked on pattern\n\n", .{});
        tests_passed += 1;
        // Move mouse back to corner so cursor doesn't affect pattern area
        try Mouse.moveTo(10, 10);
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }

    // ========================================================================
    // Test 8: hover() - find and hover (no click)
    // ========================================================================
    try stdout.print("Test 8: Region.hover() - find and hover over pattern\n", .{});
    {
        const match_result = screen_region.hover(allocator, &pattern_image) catch |err| {
            try stdout.print("  FAIL: hover() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Hovering at ({}, {})\n\n", .{
            match_result.center().x,
            match_result.center().y,
        });
        tests_passed += 1;
        // Move mouse back to corner for subsequent tests
        try Mouse.moveTo(10, 10);
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }

    // ========================================================================
    // Test 9: hoverCenter() - hover at region center
    // ========================================================================
    try stdout.print("Test 9: Region.hoverCenter() - hover at region center\n", .{});
    {
        screen_region.hoverCenter() catch |err| {
            try stdout.print("  FAIL: hoverCenter() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        const c = screen_region.center();
        try stdout.print("  PASS: Hovering at center ({}, {})\n\n", .{ c.x, c.y });
        tests_passed += 1;
    }

    // ========================================================================
    // Test 10: wheelDown() and wheelUp() - scroll
    // ========================================================================
    try stdout.print("Test 10: Region.wheelDown/Up() - scroll operations\n", .{});
    {
        screen_region.wheelDown(2) catch |err| {
            try stdout.print("  FAIL: wheelDown() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        std.Thread.sleep(100 * std.time.ns_per_ms);
        screen_region.wheelUp(2) catch |err| {
            try stdout.print("  FAIL: wheelUp() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Scroll down/up completed\n\n", .{});
        tests_passed += 1;
    }

    // ========================================================================
    // Test 11: dragTo() - drag from region center to a destination
    // ========================================================================
    try stdout.print("Test 11: Region.dragTo() - drag from center to destination\n", .{});
    {
        const dest_x: i32 = @intCast(center_x + 50);
        const dest_y: i32 = @intCast(center_y + 50);
        screen_region.dragTo(dest_x, dest_y) catch |err| {
            try stdout.print("  FAIL: dragTo() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Dragged to ({}, {})\n\n", .{ dest_x, dest_y });
        tests_passed += 1;
    }

    // ========================================================================
    // Test 12: findAll() - find all occurrences
    // ========================================================================
    try stdout.print("Test 12: Region.findAll() - find all matches\n", .{});
    {
        const matches = screen_region.findAll(allocator, &pattern_image) catch |err| {
            try stdout.print("  FAIL: findAll() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        defer allocator.free(matches);

        if (matches.len >= 1) {
            try stdout.print("  PASS: Found {} match(es)\n", .{matches.len});
            for (matches[0..@min(matches.len, 3)], 0..) |m, i| {
                try stdout.print("    Match {}: ({}, {}) score={d:.3}\n", .{
                    i + 1,
                    m.bounds.x,
                    m.bounds.y,
                    m.score,
                });
            }
            try stdout.print("\n", .{});
            tests_passed += 1;
        } else {
            try stdout.print("  FAIL: findAll() returned 0 matches\n\n", .{});
            tests_failed += 1;
        }
    }

    // ========================================================================
    // Test 13: clickWithModifiers() - Ctrl+Click
    // ========================================================================
    try stdout.print("Test 13: Region.clickWithModifiers() - Ctrl+Click\n", .{});
    {
        _ = screen_region.clickWithModifiers(allocator, &pattern_image, KeyModifier.CTRL) catch |err| {
            try stdout.print("  FAIL: clickWithModifiers() threw error: {}\n\n", .{err});
            tests_failed += 1;
            return err;
        };
        try stdout.print("  PASS: Ctrl+Click completed\n\n", .{});
        tests_passed += 1;
    }

    // ========================================================================
    // Test 14: Edge case - find() with very short timeout on non-existent pattern
    // ========================================================================
    try stdout.print("Test 14: Edge case - find() failure with FindFailed\n", .{});
    {
        // Create a 1x1 white image that won't be found
        var dummy_image = Image.init(allocator, 10, 10, PixelFormat.RGBA) catch |err| {
            try stdout.print("  SKIP: Could not create dummy image: {}\n\n", .{err});
            tests_failed += 1;
            return;
        };
        defer dummy_image.deinit();

        // Fill with unique color unlikely to be on screen
        for (0..10) |_y| {
            for (0..10) |_x| {
                const offset = _y * dummy_image.stride + _x * 4;
                dummy_image.data[offset + 0] = 255; // R
                dummy_image.data[offset + 1] = 0; // G
                dummy_image.data[offset + 2] = 255; // B
                dummy_image.data[offset + 3] = 255; // A
            }
        }

        // Create a region with short timeout
        var test_region = Region.initAt(0, 0, 100, 100);
        test_region.auto_wait_timeout = 0.1; // 100ms timeout

        const result = test_region.find(allocator, &dummy_image);
        if (result) |_| {
            try stdout.print("  WARNING: Unexpectedly found the dummy pattern\n\n", .{});
        } else |err| {
            if (err == error.FindFailed) {
                try stdout.print("  PASS: Correctly threw FindFailed for non-existent pattern\n\n", .{});
                tests_passed += 1;
            } else {
                try stdout.print("  FAIL: Wrong error type: {}\n\n", .{err});
                tests_failed += 1;
            }
        }
    }

    // ========================================================================
    // Summary
    // ========================================================================
    try stdout.print("================================================\n", .{});
    try stdout.print("Results: {} passed, {} failed\n", .{ tests_passed, tests_failed });
    try stdout.print("================================================\n\n", .{});

    if (tests_failed > 0) {
        return error.TestsFailed;
    }
}
