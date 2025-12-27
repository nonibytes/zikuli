//! Type Text Example
//!
//! This example demonstrates Zikuli's keyboard automation:
//! - Typing text strings
//! - Pressing individual keys
//! - Using keyboard shortcuts (hotkeys)
//! - Modifier key combinations
//!
//! Run with: zig build run-example-type
//!
//! WARNING: This example types actual keystrokes!
//! Make sure a text editor or input field is focused.

const std = @import("std");
const zikuli = @import("zikuli");

const Keyboard = zikuli.Keyboard;
const KeySym = zikuli.KeySym;
const KeyModifier = zikuli.KeyModifier;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli Type Text Example\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    try stdout.print("WARNING: This example will type real keystrokes!\n", .{});
    try stdout.print("Make sure you have a text editor focused.\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Starting in 3 seconds...\n", .{});

    // Give user time to focus a text field
    std.Thread.sleep(3 * std.time.ns_per_s);

    // Step 1: Type a simple string
    try stdout.print("\nStep 1: Typing 'Hello, Zikuli!'...\n", .{});
    try Keyboard.typeString("Hello, Zikuli!");
    try stdout.print("  Done!\n", .{});

    std.Thread.sleep(500 * std.time.ns_per_ms);

    // Step 2: Press Enter key
    try stdout.print("\nStep 2: Pressing Enter...\n", .{});
    try Keyboard.press(KeySym.Return);
    try stdout.print("  Done!\n", .{});

    std.Thread.sleep(500 * std.time.ns_per_ms);

    // Step 3: Type with mixed case
    try stdout.print("\nStep 3: Typing 'This Is Mixed Case'...\n", .{});
    try Keyboard.typeString("This Is Mixed Case");
    try stdout.print("  Done!\n", .{});

    std.Thread.sleep(500 * std.time.ns_per_ms);

    // Step 4: Press Enter
    try Keyboard.press(KeySym.Return);

    // Step 5: Type numbers and symbols
    try stdout.print("\nStep 4: Typing numbers and symbols...\n", .{});
    try Keyboard.typeString("Numbers: 12345");
    try Keyboard.press(KeySym.Return);
    try Keyboard.typeString("Symbols: !@#$%");
    try stdout.print("  Done!\n", .{});

    std.Thread.sleep(500 * std.time.ns_per_ms);

    // Step 6: Press Enter twice for blank line
    try Keyboard.press(KeySym.Return);
    try Keyboard.press(KeySym.Return);

    // Step 7: Use keyboard shortcut (Ctrl+A to select all)
    try stdout.print("\nStep 5: Keyboard shortcuts demo...\n", .{});
    try stdout.print("  Note: Ctrl+A (select all) will be pressed\n", .{});

    // Give user a moment
    std.Thread.sleep(1 * std.time.ns_per_s);

    // Select all with Ctrl+A
    try Keyboard.pressWithModifiers('a', KeyModifier.CTRL);
    try stdout.print("  Ctrl+A pressed!\n", .{});

    std.Thread.sleep(500 * std.time.ns_per_ms);

    // Press End to deselect and go to end
    try Keyboard.press(KeySym.End);

    // Step 8: Arrow key navigation
    try stdout.print("\nStep 6: Arrow key navigation...\n", .{});
    try Keyboard.press(KeySym.Home); // Go to beginning
    std.Thread.sleep(200 * std.time.ns_per_ms);

    // Move right 5 times
    var i: u32 = 0;
    while (i < 5) : (i += 1) {
        try Keyboard.press(KeySym.Right);
        std.Thread.sleep(100 * std.time.ns_per_ms);
    }
    try stdout.print("  Moved cursor 5 positions right\n", .{});

    // Step 9: Type at cursor position
    try Keyboard.typeString("[INSERTED]");
    try stdout.print("  Inserted text at cursor position\n", .{});

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Type text example completed!\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
