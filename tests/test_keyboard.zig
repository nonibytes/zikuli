//! Keyboard Control Integration Test
//!
//! This test verifies actual keyboard control functionality using XTest.
//! It types text and verifies the keystrokes are sent.
//!
//! Requirements:
//! - X11 display (DISPLAY environment variable)
//! - XTest extension available
//!
//! Run with: zig build test-keyboard

const std = @import("std");
const zikuli = @import("zikuli");
const Keyboard = zikuli.Keyboard;
const KeySym = zikuli.KeySym;
const KeyModifier = zikuli.KeyModifier;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli Keyboard Control Integration Test\n", .{});
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

    // Test 1: Press and release a key
    try stdout.print("Test 1: Press and release 'a' key\n", .{});
    Keyboard.press('a') catch |err| {
        try stdout.print("  FAIL: Could not press key: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Key 'a' pressed and released\n\n", .{});

    // Test 2: Press a function key
    try stdout.print("Test 2: Press F1 key\n", .{});
    Keyboard.press(KeySym.F1) catch |err| {
        try stdout.print("  FAIL: Could not press F1: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: F1 key pressed and released\n\n", .{});

    // Test 3: Press key with modifier
    try stdout.print("Test 3: Press Ctrl+C (without actual copy)\n", .{});
    Keyboard.pressWithModifiers('c', KeyModifier.CTRL) catch |err| {
        try stdout.print("  FAIL: Could not press Ctrl+C: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Ctrl+C pressed and released\n\n", .{});

    // Test 4: Press arrow keys
    try stdout.print("Test 4: Press arrow keys (Up, Down, Left, Right)\n", .{});
    const arrow_keys = [_]u32{ KeySym.Up, KeySym.Down, KeySym.Left, KeySym.Right };
    for (arrow_keys) |key| {
        Keyboard.press(key) catch |err| {
            try stdout.print("  FAIL: Could not press arrow key: {}\n", .{err});
            return err;
        };
    }
    try stdout.print("  PASS: All arrow keys pressed\n\n", .{});

    // Test 5: Type a character
    try stdout.print("Test 5: Type character 'z'\n", .{});
    Keyboard.typeChar('z') catch |err| {
        try stdout.print("  FAIL: Could not type character: {}\n", .{err});
        return err;
    };
    try stdout.print("  PASS: Character 'z' typed\n\n", .{});

    // Test 6: Verify modifier state tracking
    try stdout.print("Test 6: Modifier state tracking\n", .{});
    const state = Keyboard.getState();
    if (!state.isModifierHeld(KeyModifier.SHIFT) and !state.isModifierHeld(KeyModifier.CTRL)) {
        try stdout.print("  PASS: No modifiers held (correct initial state)\n\n", .{});
    } else {
        try stdout.print("  FAIL: Unexpected modifiers held\n", .{});
        return error.UnexpectedState;
    }

    // Summary
    try stdout.print("===========================================\n", .{});
    try stdout.print("All keyboard control tests PASSED!\n", .{});
    try stdout.print("===========================================\n\n", .{});
}
