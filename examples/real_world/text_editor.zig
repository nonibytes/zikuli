//! Real-World Text Editor Automation
//!
//! This example demonstrates automating a text editor:
//! - Launch gedit (GNOME text editor)
//! - Type text content
//! - Use keyboard shortcuts
//! - Save file
//!
//! Run with: zig build run-realworld-editor
//!
//! Prerequisites:
//! - gedit installed (sudo apt install gedit)
//! - X11 display available

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Mouse = zikuli.Mouse;
const Keyboard = zikuli.Keyboard;
const KeySym = zikuli.KeySym;
const KeyModifier = zikuli.KeyModifier;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Real-World Text Editor Automation\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Step 1: Launch gedit
    try stdout.print("Step 1: Launching gedit...\n", .{});

    var child = std.process.Child.init(&.{ "gedit" }, std.heap.page_allocator);
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    _ = try child.spawn();

    // Wait for gedit to open
    try stdout.print("  Waiting for gedit to open (3 seconds)...\n", .{});
    std.Thread.sleep(3 * std.time.ns_per_s);

    // Step 2: Type a title
    try stdout.print("\nStep 2: Typing content...\n", .{});
    try Keyboard.typeText("# Zikuli Automation Test");
    try Keyboard.press(KeySym.Return);
    try Keyboard.press(KeySym.Return);
    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Step 3: Type more content
    try Keyboard.typeText("This file was created automatically by Zikuli.");
    try Keyboard.press(KeySym.Return);
    try Keyboard.typeText("Zikuli is a visual GUI automation library for Zig.");
    try Keyboard.press(KeySym.Return);
    try Keyboard.press(KeySym.Return);
    std.Thread.sleep(100 * std.time.ns_per_ms);

    // Step 4: Type timestamp
    try Keyboard.typeText("Generated at: ");
    // Type current date/time
    const timestamp = std.time.timestamp();
    var buf: [64]u8 = undefined;
    const ts_str = try std.fmt.bufPrint(&buf, "{}", .{timestamp});
    try Keyboard.typeText(ts_str);
    try Keyboard.press(KeySym.Return);

    try stdout.print("  Content typed!\n", .{});

    // Step 5: Select all text (Ctrl+A)
    try stdout.print("\nStep 3: Selecting all text (Ctrl+A)...\n", .{});
    std.Thread.sleep(500 * std.time.ns_per_ms);
    try Keyboard.pressWithModifiers('a', KeyModifier.CTRL);
    std.Thread.sleep(300 * std.time.ns_per_ms);

    // Step 6: Deselect and go to end
    try Keyboard.press(KeySym.End);

    // Step 7: Add final line
    try Keyboard.press(KeySym.Return);
    try Keyboard.typeText("-- End of automated content --");

    try stdout.print("  Done!\n", .{});

    // Step 8: Show save dialog (Ctrl+S)
    try stdout.print("\nStep 4: Opening Save dialog (Ctrl+S)...\n", .{});
    std.Thread.sleep(500 * std.time.ns_per_ms);
    try Keyboard.pressWithModifiers('s', KeyModifier.CTRL);

    try stdout.print("  Save dialog should now be open.\n", .{});
    try stdout.print("  (Close gedit manually to end the demo)\n", .{});

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Text editor automation completed!\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("What was demonstrated:\n", .{});
    try stdout.print("  - Launch external application (gedit)\n", .{});
    try stdout.print("  - Type multi-line text content\n", .{});
    try stdout.print("  - Use keyboard shortcuts (Ctrl+A, Ctrl+S)\n", .{});
    try stdout.print("  - Handle special keys (Return, End)\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
