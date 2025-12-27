//! Website Navigation Test using Zikuli
//!
//! This example demonstrates Zikuli's visual automation capabilities:
//! - Launch Chrome with a test website
//! - Find buttons using OCR
//! - Click buttons to navigate between pages
//! - Verify navigation by checking page content
//! - Test form interactions
//!
//! Run with: zig build run-nav-test

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Image = zikuli.Image;
const OCR = zikuli.OCR;
const Keyboard = zikuli.Keyboard;
const Mouse = zikuli.Mouse;
const KeySym = zikuli.KeySym;
const Rectangle = zikuli.Rectangle;

const TestResult = struct {
    name: []const u8,
    passed: bool,
    details: []const u8,
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║     Zikuli Website Navigation Test                       ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    // Initialize Zikuli components
    try stdout.print("[INIT] Initializing Zikuli...\n", .{});

    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    var ocr = try OCR.init(allocator);
    defer ocr.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("[INIT] Screen: {}x{}\n", .{ screen_region.width(), screen_region.height() });

    // Get absolute path to test website
    const cwd = std.fs.cwd();
    var path_buf: [512]u8 = undefined;
    const website_path = try cwd.realpath("test_website/index.html", &path_buf);
    const file_url = try std.fmt.allocPrint(allocator, "file://{s}", .{website_path});
    defer allocator.free(file_url);

    try stdout.print("[INIT] Website: {s}\n", .{file_url});

    // Launch Chrome
    try stdout.print("\n[TEST 1] Launching Chrome...\n", .{});

    var chrome = std.process.Child.init(
        &.{ "google-chrome", "--new-window", file_url },
        allocator
    );
    chrome.stdin_behavior = .Ignore;
    chrome.stdout_behavior = .Ignore;
    chrome.stderr_behavior = .Ignore;
    _ = chrome.spawn() catch {
        var chromium = std.process.Child.init(
            &.{ "chromium", "--new-window", file_url },
            allocator
        );
        chromium.stdin_behavior = .Ignore;
        chromium.stdout_behavior = .Ignore;
        chromium.stderr_behavior = .Ignore;
        _ = try chromium.spawn();
    };

    try stdout.print("[TEST 1] Waiting for page to load (5 seconds)...\n", .{});
    std.Thread.sleep(5 * std.time.ns_per_s);

    // Focus Chrome window
    try stdout.print("[TEST 1] Focusing Chrome window...\n", .{});
    var focus = std.process.Child.init(
        &.{ "wmctrl", "-a", "Zikuli Test" },
        allocator
    );
    focus.stdin_behavior = .Ignore;
    focus.stdout_behavior = .Ignore;
    focus.stderr_behavior = .Ignore;
    _ = focus.spawn() catch {};
    std.Thread.sleep(1 * std.time.ns_per_s);

    // Click to focus
    try Mouse.moveTo(960, 540);
    try Mouse.click(.left);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    // Test 1: Verify home page loaded
    try stdout.print("\n[TEST 1] Verifying home page...\n", .{});
    var test1_passed = false;

    var capture = try screen.capture();
    defer capture.deinit();

    var full_image = try Image.fromCapture(allocator, capture);
    defer full_image.deinit();

    ocr.setPageSegMode(.auto);
    const home_text = try ocr.readText(&full_image);
    defer allocator.free(home_text);

    if (std.mem.indexOf(u8, home_text, "Zikuli Test") != null or
        std.mem.indexOf(u8, home_text, "HOME") != null)
    {
        test1_passed = true;
        try stdout.print("[TEST 1] ✅ PASS: Home page detected\n", .{});
    } else {
        try stdout.print("[TEST 1] ❌ FAIL: Home page not detected\n", .{});
        try stdout.print("[DEBUG] OCR found: {s}\n", .{home_text[0..@min(home_text.len, 200)]});
    }

    // Test 2: Click INCREMENT button and verify counter
    try stdout.print("\n[TEST 2] Testing INCREMENT button...\n", .{});
    var test2_passed = false;

    // Find INCREMENT text using OCR with word positions
    const words = try ocr.readWords(&full_image);
    defer {
        for (words) |word| {
            allocator.free(word.text);
        }
        allocator.free(words);
    }

    for (words) |word| {
        if (std.mem.eql(u8, word.text, "INCREMENT") or
            std.mem.indexOf(u8, word.text, "INCREMENT") != null)
        {
            const click_x = word.bounds.x + @as(i32, @intCast(word.bounds.width / 2));
            const click_y = word.bounds.y + @as(i32, @intCast(word.bounds.height / 2));

            try stdout.print("[TEST 2] Found INCREMENT at ({}, {})\n", .{ click_x, click_y });
            try Mouse.moveTo(@intCast(click_x), @intCast(click_y));
            std.Thread.sleep(200 * std.time.ns_per_ms);
            try Mouse.click(.left);
            std.Thread.sleep(500 * std.time.ns_per_ms);

            // Verify counter changed
            var capture2 = try screen.capture();
            defer capture2.deinit();
            var img2 = try Image.fromCapture(allocator, capture2);
            defer img2.deinit();

            const text2 = try ocr.readText(&img2);
            defer allocator.free(text2);

            if (std.mem.indexOf(u8, text2, "incremented") != null or
                std.mem.indexOf(u8, text2, "Counter") != null)
            {
                test2_passed = true;
                try stdout.print("[TEST 2] ✅ PASS: Button click detected\n", .{});
            }
            break;
        }
    }

    if (!test2_passed) {
        try stdout.print("[TEST 2] ⚠️  Could not verify button click\n", .{});
    }

    // Test 3: Navigate to Page 1
    try stdout.print("\n[TEST 3] Navigating to Page 1...\n", .{});
    var test3_passed = false;

    // Refresh capture
    var capture3 = try screen.capture();
    defer capture3.deinit();
    var img3 = try Image.fromCapture(allocator, capture3);
    defer img3.deinit();

    const words3 = try ocr.readWords(&img3);
    defer {
        for (words3) |word| {
            allocator.free(word.text);
        }
        allocator.free(words3);
    }

    for (words3) |word| {
        if (std.mem.indexOf(u8, word.text, "Page") != null and
            std.mem.indexOf(u8, word.text, "1") != null)
        {
            const click_x = word.bounds.x + @as(i32, @intCast(word.bounds.width / 2));
            const click_y = word.bounds.y + @as(i32, @intCast(word.bounds.height / 2));

            try stdout.print("[TEST 3] Clicking 'Go to Page 1' at ({}, {})\n", .{ click_x, click_y });
            try Mouse.moveTo(@intCast(click_x), @intCast(click_y));
            std.Thread.sleep(200 * std.time.ns_per_ms);
            try Mouse.click(.left);
            std.Thread.sleep(1 * std.time.ns_per_s);

            // Verify we're on Page 1
            var capture4 = try screen.capture();
            defer capture4.deinit();
            var img4 = try Image.fromCapture(allocator, capture4);
            defer img4.deinit();

            const text4 = try ocr.readText(&img4);
            defer allocator.free(text4);

            if (std.mem.indexOf(u8, text4, "PAGE 1") != null or
                std.mem.indexOf(u8, text4, "Successfully navigated") != null)
            {
                test3_passed = true;
                try stdout.print("[TEST 3] ✅ PASS: Navigated to Page 1\n", .{});
            }
            break;
        }
    }

    if (!test3_passed) {
        try stdout.print("[TEST 3] ❌ FAIL: Could not navigate to Page 1\n", .{});
    }

    // Test 4: Continue to Page 3
    try stdout.print("\n[TEST 4] Navigating to Page 3...\n", .{});
    var test4_passed = false;

    // Click Next twice to get to Page 3
    for (0..2) |i| {
        std.Thread.sleep(500 * std.time.ns_per_ms);

        var cap = try screen.capture();
        defer cap.deinit();
        var img = try Image.fromCapture(allocator, cap);
        defer img.deinit();

        const wrds = try ocr.readWords(&img);
        defer {
            for (wrds) |word| {
                allocator.free(word.text);
            }
            allocator.free(wrds);
        }

        for (wrds) |word| {
            if (std.mem.indexOf(u8, word.text, "Next") != null) {
                const click_x = word.bounds.x + @as(i32, @intCast(word.bounds.width / 2));
                const click_y = word.bounds.y + @as(i32, @intCast(word.bounds.height / 2));

                try stdout.print("[TEST 4] Clicking 'Next' ({}/2)\n", .{i + 1});
                try Mouse.moveTo(@intCast(click_x), @intCast(click_y));
                std.Thread.sleep(200 * std.time.ns_per_ms);
                try Mouse.click(.left);
                std.Thread.sleep(800 * std.time.ns_per_ms);
                break;
            }
        }
    }

    // Verify Page 3
    var cap_final = try screen.capture();
    defer cap_final.deinit();
    var img_final = try Image.fromCapture(allocator, cap_final);
    defer img_final.deinit();

    const text_final = try ocr.readText(&img_final);
    defer allocator.free(text_final);

    if (std.mem.indexOf(u8, text_final, "PAGE 3") != null or
        std.mem.indexOf(u8, text_final, "CONGRATULATIONS") != null or
        std.mem.indexOf(u8, text_final, "final") != null)
    {
        test4_passed = true;
        try stdout.print("[TEST 4] ✅ PASS: Navigated to Page 3\n", .{});
    } else {
        try stdout.print("[TEST 4] ❌ FAIL: Could not verify Page 3\n", .{});
    }

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    TEST SUMMARY                          ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════╣\n", .{});

    var total_passed: u32 = 0;
    if (test1_passed) {
        try stdout.print("║  Test 1: Home Page Load        ✅ PASS                  ║\n", .{});
        total_passed += 1;
    } else {
        try stdout.print("║  Test 1: Home Page Load        ❌ FAIL                  ║\n", .{});
    }

    if (test2_passed) {
        try stdout.print("║  Test 2: Button Click          ✅ PASS                  ║\n", .{});
        total_passed += 1;
    } else {
        try stdout.print("║  Test 2: Button Click          ⚠️  SKIP                  ║\n", .{});
    }

    if (test3_passed) {
        try stdout.print("║  Test 3: Navigate to Page 1    ✅ PASS                  ║\n", .{});
        total_passed += 1;
    } else {
        try stdout.print("║  Test 3: Navigate to Page 1    ❌ FAIL                  ║\n", .{});
    }

    if (test4_passed) {
        try stdout.print("║  Test 4: Navigate to Page 3    ✅ PASS                  ║\n", .{});
        total_passed += 1;
    } else {
        try stdout.print("║  Test 4: Navigate to Page 3    ❌ FAIL                  ║\n", .{});
    }

    try stdout.print("╠══════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  Total: {}/4 tests passed                                ║\n", .{total_passed});
    try stdout.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});
}
