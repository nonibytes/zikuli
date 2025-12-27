//! Click Debug Test
//!
//! Diagnoses multi-monitor clicking issues by:
//! 1. Finding which monitor Chrome is on
//! 2. Capturing from the correct monitor
//! 3. Showing OCR results with coordinates
//! 4. Testing clicks on the correct screen

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Mouse = zikuli.Mouse;
const Monitors = zikuli.Monitors;
const Image = zikuli.Image;
const OCR = zikuli.OCR;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n=== CLICK DEBUG TEST ===\n\n", .{});

    // Step 1: Get current mouse position
    const mouse_pos = try Mouse.getPosition();
    try stdout.print("Current mouse position: ({d}, {d})\n", .{ mouse_pos.x, mouse_pos.y });

    // Step 2: Determine which monitor the mouse is on
    var monitors = try Monitors.init(allocator);
    defer monitors.deinit();

    const all_monitors = try monitors.getAll();
    defer monitors.freeMonitors(all_monitors);

    try stdout.print("\nMonitor layout:\n", .{});
    var mouse_monitor_id: u32 = 0;
    for (all_monitors) |mon| {
        const contains_mouse = mon.bounds.contains(mouse_pos);
        try stdout.print("  Monitor {d} ({s}): x={d}-{d}, y={d}-{d} {s}\n", .{
            mon.id,
            mon.getName(),
            mon.bounds.x,
            mon.bounds.x + @as(i32, @intCast(mon.bounds.width)),
            mon.bounds.y,
            mon.bounds.y + @as(i32, @intCast(mon.bounds.height)),
            if (contains_mouse) "<-- MOUSE HERE" else "",
        });
        if (contains_mouse) {
            mouse_monitor_id = mon.id;
        }
    }

    // Step 3: Capture from the VIRTUAL screen (all monitors) to see everything
    try stdout.print("\nCapturing virtual screen (all monitors)...\n", .{});
    var virtual_screen = try Screen.virtual(allocator);
    defer virtual_screen.deinit();

    try stdout.print("Virtual screen bounds: x={d}, y={d}, {d}x{d}\n", .{
        virtual_screen.bounds.x,
        virtual_screen.bounds.y,
        virtual_screen.bounds.width,
        virtual_screen.bounds.height,
    });

    var capture = try virtual_screen.capture();
    defer capture.deinit();

    var full_image = try Image.fromCapture(allocator, capture);
    defer full_image.deinit();

    try stdout.print("Captured image: {d}x{d}\n", .{ full_image.width, full_image.height });

    // Step 4: Run OCR and show what was found
    var ocr = try OCR.init(allocator);
    defer ocr.deinit();

    const words = try ocr.readWords(&full_image);
    defer {
        for (words) |word| {
            allocator.free(word.text);
        }
        allocator.free(words);
    }

    try stdout.print("\nOCR found {d} words. Looking for buttons...\n", .{words.len});

    var button_found = false;
    for (words) |word| {
        // Look for buttons we care about
        if (std.mem.indexOf(u8, word.text, "INCREMENT") != null or
            std.mem.indexOf(u8, word.text, "RESET") != null or
            std.mem.indexOf(u8, word.text, "Page") != null or
            std.mem.indexOf(u8, word.text, "Home") != null or
            std.mem.indexOf(u8, word.text, "HOME") != null)
        {
            const click_x = word.bounds.x + @as(i32, @intCast(word.bounds.width / 2));
            const click_y = word.bounds.y + @as(i32, @intCast(word.bounds.height / 2));

            // Check which monitor this is on
            var word_monitor: []const u8 = "unknown";
            for (all_monitors) |mon| {
                if (mon.bounds.contains(.{ .x = click_x, .y = click_y })) {
                    word_monitor = mon.getName();
                    break;
                }
            }

            try stdout.print("  Found '{s}' at ({d},{d})-({d},{d}) -> click ({d},{d}) on {s}\n", .{
                word.text,
                word.bounds.x,
                word.bounds.y,
                word.bounds.x + @as(i32, @intCast(word.bounds.width)),
                word.bounds.y + @as(i32, @intCast(word.bounds.height)),
                click_x,
                click_y,
                word_monitor,
            });
            button_found = true;
        }
    }

    if (!button_found) {
        try stdout.print("  No buttons found! Make sure the test website is open.\n", .{});
    }

    // Let's also print ALL words to see what OCR is finding
    try stdout.print("\nFirst 50 words found by OCR:\n", .{});
    for (words, 0..) |word, i| {
        if (i >= 50) break;
        try stdout.print("  [{d}] '{s}' at ({d},{d})\n", .{ i, word.text, word.bounds.x, word.bounds.y });
    }

    // Step 5: Try clicking on a specific button
    try stdout.print("\nLooking for INCREMENT button to click...\n", .{});
    for (words) |word| {
        if (std.mem.eql(u8, word.text, "INCREMENT")) {
            const click_x = word.bounds.x + @as(i32, @intCast(word.bounds.width / 2));
            const click_y = word.bounds.y + @as(i32, @intCast(word.bounds.height / 2));
            try stdout.print("  Found INCREMENT at ({d},{d}), clicking...\n", .{ click_x, click_y });
            try Mouse.moveTo(click_x, click_y);
            std.Thread.sleep(500 * std.time.ns_per_ms);
            try Mouse.click(.left);
            std.Thread.sleep(500 * std.time.ns_per_ms);
            try stdout.print("  Clicked! Check if the counter incremented.\n", .{});
            break;
        }
    } else {
        try stdout.print("  INCREMENT button not found. Trying HOME button...\n", .{});
        for (words) |word| {
            if (std.mem.eql(u8, word.text, "HOME")) {
                const click_x = word.bounds.x + @as(i32, @intCast(word.bounds.width / 2));
                const click_y = word.bounds.y + @as(i32, @intCast(word.bounds.height / 2));
                try stdout.print("  Found HOME at ({d},{d}), clicking...\n", .{ click_x, click_y });
                try Mouse.moveTo(click_x, click_y);
                std.Thread.sleep(500 * std.time.ns_per_ms);
                try Mouse.click(.left);
                std.Thread.sleep(500 * std.time.ns_per_ms);
                try stdout.print("  Clicked! Check if the page navigated.\n", .{});
                break;
            }
        }
    }

    // Step 6: Move mouse to center of mouse's current monitor
    try stdout.print("\nMoving mouse to center of monitor {d}...\n", .{mouse_monitor_id});
    var current_screen = try Screen.get(allocator, @intCast(mouse_monitor_id));
    defer current_screen.deinit();

    const center_x = current_screen.bounds.x + @as(i32, @intCast(current_screen.bounds.width / 2));
    const center_y = current_screen.bounds.y + @as(i32, @intCast(current_screen.bounds.height / 2));

    try stdout.print("Moving to ({d}, {d})...\n", .{ center_x, center_y });
    try Mouse.moveTo(center_x, center_y);
    std.Thread.sleep(500 * std.time.ns_per_ms);

    const new_pos = try Mouse.getPosition();
    try stdout.print("Mouse now at: ({d}, {d})\n", .{ new_pos.x, new_pos.y });

    try stdout.print("\n=== END DEBUG TEST ===\n", .{});
}
