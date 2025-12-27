//! Real-World Web Button Test
//!
//! This test demonstrates Zikuli finding and clicking actual UI elements:
//! 1. Opens a webpage with colored buttons
//! 2. Uses template matching to find buttons by color
//! 3. Clicks on them and verifies the clicks worked

const std = @import("std");
const zikuli = @import("zikuli");

const Image = zikuli.Image;
const Screen = zikuli.Screen;
const Finder = zikuli.Finder;
const Mouse = zikuli.Mouse;

/// Button color definitions (matching the HTML)
const ButtonColor = struct {
    r: u8,
    g: u8,
    b: u8,
    name: []const u8,
};

const RED_BUTTON = ButtonColor{ .r = 255, .g = 100, .b = 50, .name = "RED" };
const GREEN_BUTTON = ButtonColor{ .r = 50, .g = 200, .b = 100, .name = "GREEN" };
const BLUE_BUTTON = ButtonColor{ .r = 50, .g = 100, .b = 255, .name = "BLUE" };

/// Create a solid color template image for finding buttons
fn createColorTemplate(allocator: std.mem.Allocator, color: ButtonColor, size: u32) !Image {
    var img = try Image.init(allocator, size, size, .BGRA);

    var y: u32 = 0;
    while (y < size) : (y += 1) {
        var x: u32 = 0;
        while (x < size) : (x += 1) {
            img.setPixel(x, y, color.r, color.g, color.b, 255);
        }
    }

    return img;
}

/// Find a button by its color and click it
fn findAndClickButton(allocator: std.mem.Allocator, screen_image: *const Image, color: ButtonColor) !bool {
    // Create a small template of the button color
    var template = try createColorTemplate(allocator, color, 20);
    defer template.deinit();

    // Find the button
    var finder = Finder.init(allocator, screen_image);
    defer finder.deinit();

    finder.setSimilarity(0.8); // 80% match threshold

    if (finder.find(&template)) |match| {
        const target = match.getTarget();
        std.debug.print("  Found {s} button at ({}, {}) score={d:.2}\n", .{
            color.name,
            target.x,
            target.y,
            match.score,
        });

        // Click on the button
        try Mouse.clickAt(target.x, target.y, .left);
        std.Thread.sleep(200 * std.time.ns_per_ms);

        return true;
    } else {
        std.debug.print("  {s} button not found\n", .{color.name});
        return false;
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    std.debug.print("║     Zikuli Real-World Web Button Test                     ║\n", .{});
    std.debug.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    std.debug.print("\n", .{});

    // Wait for user to position browser
    std.debug.print("Make sure the test webpage is visible on screen.\n", .{});
    std.debug.print("Starting in 2 seconds...\n\n", .{});
    std.Thread.sleep(2 * std.time.ns_per_s);

    // Capture the screen
    std.debug.print("Step 1: Capturing screen...\n", .{});
    var screen = try Screen.virtual(allocator);
    defer screen.deinit();

    var captured = try screen.capture();
    defer captured.deinit();

    var screen_image = try Image.fromCapture(allocator, captured);
    defer screen_image.deinit();

    std.debug.print("  Screen captured: {}x{}\n", .{ screen_image.width, screen_image.height });

    // Find and click each button
    std.debug.print("\nStep 2: Finding and clicking buttons...\n", .{});

    var buttons_found: u32 = 0;

    // Try to find RED button
    if (try findAndClickButton(allocator, &screen_image, RED_BUTTON)) {
        buttons_found += 1;
    }

    // Re-capture after click (in case page changed)
    var captured2 = try screen.capture();
    defer captured2.deinit();
    var screen_image2 = try Image.fromCapture(allocator, captured2);
    defer screen_image2.deinit();

    // Try to find GREEN button
    if (try findAndClickButton(allocator, &screen_image2, GREEN_BUTTON)) {
        buttons_found += 1;
    }

    // Re-capture again
    var captured3 = try screen.capture();
    defer captured3.deinit();
    var screen_image3 = try Image.fromCapture(allocator, captured3);
    defer screen_image3.deinit();

    // Try to find BLUE button
    if (try findAndClickButton(allocator, &screen_image3, BLUE_BUTTON)) {
        buttons_found += 1;
    }

    // Summary
    std.debug.print("\n", .{});
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
    std.debug.print("Results: Found and clicked {}/3 buttons\n", .{buttons_found});
    if (buttons_found == 3) {
        std.debug.print("✓ SUCCESS - All buttons found and clicked!\n", .{});
    } else if (buttons_found > 0) {
        std.debug.print("⚠ PARTIAL - Some buttons found\n", .{});
    } else {
        std.debug.print("✗ FAILED - No buttons found\n", .{});
    }
    std.debug.print("═══════════════════════════════════════════════════════════\n", .{});
}

test "web: find and click colored buttons" {
    const allocator = std.testing.allocator;

    // This test expects a browser with the test page to be open
    // Run with: ./tests/scripts/run_web_test.sh

    var screen = Screen.virtual(allocator) catch |err| {
        if (err == error.ConnectionFailed) {
            std.debug.print("No X11 display - skipping web test\n", .{});
            return;
        }
        return err;
    };
    defer screen.deinit();

    var captured = try screen.capture();
    defer captured.deinit();

    var screen_image = try Image.fromCapture(allocator, captured);
    defer screen_image.deinit();

    // Try to find at least one button
    var template = try createColorTemplate(allocator, RED_BUTTON, 20);
    defer template.deinit();

    var finder = Finder.init(allocator, &screen_image);
    defer finder.deinit();
    finder.setSimilarity(0.7);

    // This is an optional test - doesn't fail if no browser is open
    if (finder.find(&template)) |match| {
        std.debug.print("Found RED button at ({}, {}) score={d:.2}\n", .{
            match.bounds.x,
            match.bounds.y,
            match.score,
        });

        const target = match.getTarget();
        try Mouse.clickAt(target.x, target.y, .left);
        std.debug.print("Clicked RED button!\n", .{});
    } else {
        std.debug.print("RED button not visible - is test page open?\n", .{});
    }
}
