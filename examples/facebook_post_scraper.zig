//! Facebook Post Scraper using Zikuli
//!
//! This example demonstrates using Zikuli to:
//! - Launch Chrome browser
//! - Navigate to a Facebook profile
//! - Capture screen regions
//! - Extract text using OCR
//! - Scroll using keyboard automation
//! - Collect post content
//!
//! Prerequisites:
//! - Chrome installed (google-chrome or chromium)
//! - X11 display available
//! - User logged into Facebook in Chrome
//!
//! Run with: zig build run-fb-scraper

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Region = zikuli.Region;
const Image = zikuli.Image;
const OCR = zikuli.OCR;
const Keyboard = zikuli.Keyboard;
const KeySym = zikuli.KeySym;
const Rectangle = zikuli.Rectangle;

const FACEBOOK_PROFILE = "https://www.facebook.com/0xSojalSec";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Facebook Post Scraper - Zikuli Automation\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Step 1: Initialize screen and OCR
    try stdout.print("Step 1: Initializing Zikuli components...\n", .{});

    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    var ocr = try OCR.init(allocator);
    defer ocr.deinit();

    const screen_region = screen.asRegion();
    try stdout.print("  Screen: {}x{} pixels\n", .{ screen_region.width(), screen_region.height() });

    // Step 2: Launch Chrome with the Facebook profile URL
    try stdout.print("\nStep 2: Launching Chrome...\n", .{});
    try stdout.print("  URL: {s}\n", .{FACEBOOK_PROFILE});

    var chrome = std.process.Child.init(
        &.{ "google-chrome", "--new-window", FACEBOOK_PROFILE },
        allocator
    );
    chrome.stdin_behavior = .Ignore;
    chrome.stdout_behavior = .Ignore;
    chrome.stderr_behavior = .Ignore;
    _ = chrome.spawn() catch {
        // Try chromium if google-chrome not found
        var chromium = std.process.Child.init(
            &.{ "chromium", "--new-window", FACEBOOK_PROFILE },
            allocator
        );
        chromium.stdin_behavior = .Ignore;
        chromium.stdout_behavior = .Ignore;
        chromium.stderr_behavior = .Ignore;
        _ = try chromium.spawn();
    };

    // Wait for Chrome to open and page to load
    try stdout.print("  Waiting for page to load (8 seconds)...\n", .{});
    std.Thread.sleep(8 * std.time.ns_per_s);

    // Step 3: Focus Chrome window using wmctrl (more reliable)
    try stdout.print("\nStep 3: Focusing Chrome window...\n", .{});

    // Use wmctrl to activate Chrome window
    var activate_chrome = std.process.Child.init(
        &.{ "wmctrl", "-a", "Facebook" },
        allocator
    );
    activate_chrome.stdin_behavior = .Ignore;
    activate_chrome.stdout_behavior = .Ignore;
    activate_chrome.stderr_behavior = .Ignore;
    _ = activate_chrome.spawn() catch {
        // Fallback to xdotool
        var focus_chrome = std.process.Child.init(
            &.{ "xdotool", "search", "--name", "Facebook", "windowactivate", "--sync" },
            allocator
        );
        focus_chrome.stdin_behavior = .Ignore;
        focus_chrome.stdout_behavior = .Ignore;
        focus_chrome.stderr_behavior = .Ignore;
        _ = focus_chrome.spawn() catch {};
    };
    std.Thread.sleep(2 * std.time.ns_per_s);

    // Give user time to verify Chrome is visible
    try stdout.print("  \n", .{});
    try stdout.print("  *** PLEASE VERIFY: Chrome with Facebook should now be visible ***\n", .{});
    try stdout.print("  *** Starting scan in 3 seconds... ***\n", .{});
    try stdout.print("  \n", .{});
    std.Thread.sleep(3 * std.time.ns_per_s);

    // Click in center of screen to ensure focus
    const center_x = screen_region.width() / 2;
    const center_y = screen_region.height() / 2;
    try zikuli.Mouse.moveTo(@intCast(center_x), @intCast(center_y));
    try zikuli.Mouse.click(.left);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    try stdout.print("  Starting OCR scan...\n", .{});

    // Step 4: Define the content area (right side where posts appear)
    // Facebook posts typically appear in the center-right of the screen
    const content_x: u32 = screen_region.width() / 3;
    const content_width: u32 = screen_region.width() * 2 / 3;
    const content_height: u32 = screen_region.height();

    try stdout.print("\nStep 4: Content region configured\n", .{});
    try stdout.print("  x={}, width={}, height={}\n", .{
        content_x, content_width, content_height
    });

    // Step 5: Collect posts
    try stdout.print("\nStep 5: Scanning for posts (10 scroll iterations)...\n\n", .{});

    var all_text = std.ArrayList(u8).empty;
    defer all_text.deinit(allocator);

    var post_count: usize = 0;
    const max_scrolls: usize = 10;

    for (0..max_scrolls) |scroll_num| {
        try stdout.print("  Scroll {}/{}...\n", .{ scroll_num + 1, max_scrolls });

        // Capture the content region
        var capture = try screen.capture();
        defer capture.deinit();

        var full_image = try Image.fromCapture(allocator, capture);
        defer full_image.deinit();

        // Extract the content region (where posts are)
        const content_rect = Rectangle.init(
            @intCast(content_x),
            0,
            content_width,
            content_height
        );

        var content_img = try full_image.getSubImage(content_rect);
        defer content_img.deinit();

        // OCR the content
        ocr.setPageSegMode(.auto);
        const text = try ocr.readText(&content_img);
        defer allocator.free(text);

        if (text.len > 50) {
            try stdout.print("    Found {} characters of text\n", .{ text.len });

            // Add separator and text
            try all_text.appendSlice(allocator, "\n\n--- SCROLL ");
            var num_buf: [16]u8 = undefined;
            const num_str = try std.fmt.bufPrint(&num_buf, "{}", .{scroll_num + 1});
            try all_text.appendSlice(allocator, num_str);
            try all_text.appendSlice(allocator, " ---\n\n");
            try all_text.appendSlice(allocator, text);

            post_count += 1;
        } else {
            try stdout.print("    (minimal text detected)\n", .{});
        }

        // Scroll down using Page Down key
        try Keyboard.press(KeySym.Page_Down);

        // Wait for content to load
        std.Thread.sleep(800 * std.time.ns_per_ms);
    }

    // Step 4: Output results
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Extraction Complete!\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Total scrolls with content: {}\n", .{post_count});
    try stdout.print("Total characters extracted: {}\n", .{all_text.items.len});
    try stdout.print("\n", .{});

    // Save to file
    const output_path = "/tmp/facebook_posts_extracted.txt";
    const file = try std.fs.cwd().createFile(output_path, .{});
    defer file.close();
    try file.writeAll(all_text.items);

    try stdout.print("Output saved to: {s}\n", .{output_path});
    try stdout.print("\n", .{});

    // Print preview
    try stdout.print("--- Preview (first 2000 chars) ---\n\n", .{});
    const preview_len = @min(all_text.items.len, 2000);
    try stdout.print("{s}\n", .{all_text.items[0..preview_len]});

    if (all_text.items.len > 2000) {
        try stdout.print("\n... (truncated, see full output in {s})\n", .{output_path});
    }
}
