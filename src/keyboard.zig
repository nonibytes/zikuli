//! Keyboard - Synthetic keyboard input via XTest extension
//!
//! Provides keyboard control using the X11 XTest extension.
//! Based on SikuliX Key.java and RobotDesktop.java analysis:
//! - Type text using XTestFakeKeyEvent
//! - Handle modifier keys (Ctrl, Shift, Alt, Meta)
//! - Support special keys (F1-F12, arrows, etc.)
//!
//! Key mapping:
//! - X11 keysyms map to physical key positions
//! - Characters are converted to keysyms via XStringToKeysym
//! - Shifted characters need Shift modifier
//!
//! ## Thread Safety
//!
//! **WARNING: This module is NOT thread-safe.**
//!
//! The keyboard state is shared mutable state without synchronization.
//! All Keyboard operations must be called from a single thread.
//! The X11 connection is shared with the Mouse module (xtest.zig).

const std = @import("std");
const geometry = @import("geometry.zig");
const platform_xtest = @import("platform/xtest.zig");
const xtest = @import("xtest.zig");
const XTestConnection = platform_xtest.XTestConnection;

/// Key delay between press and release (from SikuliX Settings)
pub const DEFAULT_KEY_DELAY_MS: u64 = 0;

/// Delay between typed characters
pub const DEFAULT_TYPE_DELAY_MS: u64 = 0;

/// X11 Keysym constants for special keys
/// These map directly to X11 keysymdef.h values
pub const KeySym = struct {
    // Modifier keys
    pub const Shift_L: u32 = 0xffe1;
    pub const Shift_R: u32 = 0xffe2;
    pub const Control_L: u32 = 0xffe3;
    pub const Control_R: u32 = 0xffe4;
    pub const Caps_Lock: u32 = 0xffe5;
    pub const Shift_Lock: u32 = 0xffe6;
    pub const Meta_L: u32 = 0xffe7;
    pub const Meta_R: u32 = 0xffe8;
    pub const Alt_L: u32 = 0xffe9;
    pub const Alt_R: u32 = 0xffea;
    pub const Super_L: u32 = 0xffeb;
    pub const Super_R: u32 = 0xffec;

    // Function keys
    pub const F1: u32 = 0xffbe;
    pub const F2: u32 = 0xffbf;
    pub const F3: u32 = 0xffc0;
    pub const F4: u32 = 0xffc1;
    pub const F5: u32 = 0xffc2;
    pub const F6: u32 = 0xffc3;
    pub const F7: u32 = 0xffc4;
    pub const F8: u32 = 0xffc5;
    pub const F9: u32 = 0xffc6;
    pub const F10: u32 = 0xffc7;
    pub const F11: u32 = 0xffc8;
    pub const F12: u32 = 0xffc9;

    // TTY function keys
    pub const BackSpace: u32 = 0xff08;
    pub const Tab: u32 = 0xff09;
    pub const Return: u32 = 0xff0d;
    pub const Pause: u32 = 0xff13;
    pub const Scroll_Lock: u32 = 0xff14;
    pub const Escape: u32 = 0xff1b;
    pub const Delete: u32 = 0xffff;

    // Cursor control
    pub const Home: u32 = 0xff50;
    pub const Left: u32 = 0xff51;
    pub const Up: u32 = 0xff52;
    pub const Right: u32 = 0xff53;
    pub const Down: u32 = 0xff54;
    pub const Page_Up: u32 = 0xff55;
    pub const Page_Down: u32 = 0xff56;
    pub const End: u32 = 0xff57;
    pub const Insert: u32 = 0xff63;

    // Misc
    pub const Print: u32 = 0xff61;
    pub const Menu: u32 = 0xff67;
    pub const Num_Lock: u32 = 0xff7f;

    // Space
    pub const space: u32 = 0x0020;
};

/// Modifier key flags (matching SikuliX KeyModifier.java)
pub const Modifier = struct {
    pub const SHIFT: u32 = 1 << 0;
    pub const CTRL: u32 = 1 << 1;
    pub const ALT: u32 = 1 << 2;
    pub const META: u32 = 1 << 3;
    pub const SUPER: u32 = 1 << 4;

    pub fn toKeysym(mod: u32) ?u32 {
        if (mod & SHIFT != 0) return KeySym.Shift_L;
        if (mod & CTRL != 0) return KeySym.Control_L;
        if (mod & ALT != 0) return KeySym.Alt_L;
        if (mod & META != 0) return KeySym.Meta_L;
        if (mod & SUPER != 0) return KeySym.Super_L;
        return null;
    }
};

/// Keyboard state for tracking held keys
pub const KeyboardState = struct {
    held_modifiers: u32 = 0,
    caps_lock: bool = false,
    num_lock: bool = false,

    pub fn isModifierHeld(self: KeyboardState, mod: u32) bool {
        return (self.held_modifiers & mod) != 0;
    }

    pub fn setModifierHeld(self: *KeyboardState, mod: u32, held: bool) void {
        if (held) {
            self.held_modifiers |= mod;
        } else {
            self.held_modifiers &= ~mod;
        }
    }
};

/// Global keyboard state
var global_state: KeyboardState = .{};

/// Get the shared XTest connection (from xtest module)
/// This ensures mouse and keyboard share a single X11 display connection
fn getConnection() !*XTestConnection {
    return xtest.getConnection();
}

/// XTest keyboard controller
pub const Keyboard = struct {
    /// Press a key (by keysym)
    pub fn keyDown(keysym: u32) !void {
        const conn = try getConnection();
        const keycode = conn.keysymToKeycode(keysym);
        if (keycode == 0) {
            return error.InvalidKeysym;
        }
        try conn.keyDown(keycode);

        // Track modifier state
        if (keysym == KeySym.Shift_L or keysym == KeySym.Shift_R) {
            global_state.setModifierHeld(Modifier.SHIFT, true);
        } else if (keysym == KeySym.Control_L or keysym == KeySym.Control_R) {
            global_state.setModifierHeld(Modifier.CTRL, true);
        } else if (keysym == KeySym.Alt_L or keysym == KeySym.Alt_R) {
            global_state.setModifierHeld(Modifier.ALT, true);
        } else if (keysym == KeySym.Meta_L or keysym == KeySym.Meta_R) {
            global_state.setModifierHeld(Modifier.META, true);
        } else if (keysym == KeySym.Super_L or keysym == KeySym.Super_R) {
            global_state.setModifierHeld(Modifier.SUPER, true);
        }
    }

    /// Release a key (by keysym)
    pub fn keyUp(keysym: u32) !void {
        const conn = try getConnection();
        const keycode = conn.keysymToKeycode(keysym);
        if (keycode == 0) {
            return error.InvalidKeysym;
        }
        try conn.keyUp(keycode);

        // Track modifier state
        if (keysym == KeySym.Shift_L or keysym == KeySym.Shift_R) {
            global_state.setModifierHeld(Modifier.SHIFT, false);
        } else if (keysym == KeySym.Control_L or keysym == KeySym.Control_R) {
            global_state.setModifierHeld(Modifier.CTRL, false);
        } else if (keysym == KeySym.Alt_L or keysym == KeySym.Alt_R) {
            global_state.setModifierHeld(Modifier.ALT, false);
        } else if (keysym == KeySym.Meta_L or keysym == KeySym.Meta_R) {
            global_state.setModifierHeld(Modifier.META, false);
        } else if (keysym == KeySym.Super_L or keysym == KeySym.Super_R) {
            global_state.setModifierHeld(Modifier.SUPER, false);
        }
    }

    /// Press and release a key
    pub fn press(keysym: u32) !void {
        try keyDown(keysym);
        if (DEFAULT_KEY_DELAY_MS > 0) {
            std.Thread.sleep(DEFAULT_KEY_DELAY_MS * std.time.ns_per_ms);
        }
        try keyUp(keysym);
    }

    /// Press a key with modifiers
    /// Modifiers are released even if the key press fails (via errdefer)
    pub fn pressWithModifiers(keysym: u32, modifiers: u32) !void {
        // Track which modifiers we pressed so we can release them on error
        var ctrl_pressed = false;
        var shift_pressed = false;
        var alt_pressed = false;
        var meta_pressed = false;
        var super_pressed = false;

        // Ensure all pressed modifiers are released if anything fails
        errdefer {
            if (super_pressed) keyUp(KeySym.Super_L) catch {};
            if (meta_pressed) keyUp(KeySym.Meta_L) catch {};
            if (alt_pressed) keyUp(KeySym.Alt_L) catch {};
            if (shift_pressed) keyUp(KeySym.Shift_L) catch {};
            if (ctrl_pressed) keyUp(KeySym.Control_L) catch {};
        }

        // Press modifiers
        if (modifiers & Modifier.CTRL != 0) {
            try keyDown(KeySym.Control_L);
            ctrl_pressed = true;
        }
        if (modifiers & Modifier.SHIFT != 0) {
            try keyDown(KeySym.Shift_L);
            shift_pressed = true;
        }
        if (modifiers & Modifier.ALT != 0) {
            try keyDown(KeySym.Alt_L);
            alt_pressed = true;
        }
        if (modifiers & Modifier.META != 0) {
            try keyDown(KeySym.Meta_L);
            meta_pressed = true;
        }
        if (modifiers & Modifier.SUPER != 0) {
            try keyDown(KeySym.Super_L);
            super_pressed = true;
        }

        // Press the key
        try press(keysym);

        // Release modifiers (in reverse order)
        if (modifiers & Modifier.SUPER != 0) try keyUp(KeySym.Super_L);
        if (modifiers & Modifier.META != 0) try keyUp(KeySym.Meta_L);
        if (modifiers & Modifier.ALT != 0) try keyUp(KeySym.Alt_L);
        if (modifiers & Modifier.SHIFT != 0) try keyUp(KeySym.Shift_L);
        if (modifiers & Modifier.CTRL != 0) try keyUp(KeySym.Control_L);
    }

    /// Type a character
    /// Handles shift for uppercase and special characters
    pub fn typeChar(char: u8) !void {
        const conn = try getConnection();

        // Convert character to keysym
        // For ASCII characters, keysym is usually the same as the character code
        var keysym: u32 = char;
        var need_shift = false;

        // Check if we need shift
        if (char >= 'A' and char <= 'Z') {
            // Uppercase letter - keysym is lowercase, need shift
            keysym = char + 32; // Convert to lowercase keysym
            need_shift = true;
        } else if (isShiftedChar(char)) |unshifted| {
            keysym = unshifted;
            need_shift = true;
        }

        const keycode = conn.keysymToKeycode(keysym);
        if (keycode == 0) {
            return error.InvalidCharacter;
        }

        if (need_shift) {
            try keyDown(KeySym.Shift_L);
        }
        // Ensure Shift is released if keyPress fails
        errdefer {
            if (need_shift) keyUp(KeySym.Shift_L) catch {};
        }

        try conn.keyPress(keycode);

        if (need_shift) {
            try keyUp(KeySym.Shift_L);
        }

        if (DEFAULT_TYPE_DELAY_MS > 0) {
            std.Thread.sleep(DEFAULT_TYPE_DELAY_MS * std.time.ns_per_ms);
        }
    }

    /// Type a string of text
    pub fn typeText(text: []const u8) !void {
        for (text) |char| {
            try typeChar(char);
        }
    }

    /// Get current keyboard state
    pub fn getState() KeyboardState {
        return global_state;
    }

    /// Reset keyboard state (release all held modifiers)
    pub fn reset() !void {
        if (global_state.isModifierHeld(Modifier.SHIFT)) try keyUp(KeySym.Shift_L);
        if (global_state.isModifierHeld(Modifier.CTRL)) try keyUp(KeySym.Control_L);
        if (global_state.isModifierHeld(Modifier.ALT)) try keyUp(KeySym.Alt_L);
        if (global_state.isModifierHeld(Modifier.META)) try keyUp(KeySym.Meta_L);
        if (global_state.isModifierHeld(Modifier.SUPER)) try keyUp(KeySym.Super_L);
        global_state.held_modifiers = 0;
    }
};

/// Check if a character requires shift and return the unshifted keysym
fn isShiftedChar(char: u8) ?u32 {
    return switch (char) {
        '!' => '1',
        '@' => '2',
        '#' => '3',
        '$' => '4',
        '%' => '5',
        '^' => '6',
        '&' => '7',
        '*' => '8',
        '(' => '9',
        ')' => '0',
        '_' => '-',
        '+' => '=',
        '{' => '[',
        '}' => ']',
        '|' => '\\',
        ':' => ';',
        '"' => '\'',
        '<' => ',',
        '>' => '.',
        '?' => '/',
        '~' => '`',
        else => null,
    };
}

// ============================================================================
// Error types
// ============================================================================

pub const KeyboardError = error{
    InvalidKeysym,
    InvalidCharacter,
};

// ============================================================================
// TESTS
// ============================================================================

test "KeySym: modifier key values" {
    try std.testing.expectEqual(@as(u32, 0xffe1), KeySym.Shift_L);
    try std.testing.expectEqual(@as(u32, 0xffe3), KeySym.Control_L);
    try std.testing.expectEqual(@as(u32, 0xffe9), KeySym.Alt_L);
    try std.testing.expectEqual(@as(u32, 0xffeb), KeySym.Super_L);
}

test "KeySym: function key values" {
    try std.testing.expectEqual(@as(u32, 0xffbe), KeySym.F1);
    try std.testing.expectEqual(@as(u32, 0xffc9), KeySym.F12);
}

test "KeySym: cursor key values" {
    try std.testing.expectEqual(@as(u32, 0xff51), KeySym.Left);
    try std.testing.expectEqual(@as(u32, 0xff52), KeySym.Up);
    try std.testing.expectEqual(@as(u32, 0xff53), KeySym.Right);
    try std.testing.expectEqual(@as(u32, 0xff54), KeySym.Down);
}

test "Modifier: flag values" {
    try std.testing.expectEqual(@as(u32, 1), Modifier.SHIFT);
    try std.testing.expectEqual(@as(u32, 2), Modifier.CTRL);
    try std.testing.expectEqual(@as(u32, 4), Modifier.ALT);
    try std.testing.expectEqual(@as(u32, 8), Modifier.META);
    try std.testing.expectEqual(@as(u32, 16), Modifier.SUPER);
}

test "Modifier: toKeysym" {
    try std.testing.expectEqual(@as(?u32, KeySym.Shift_L), Modifier.toKeysym(Modifier.SHIFT));
    try std.testing.expectEqual(@as(?u32, KeySym.Control_L), Modifier.toKeysym(Modifier.CTRL));
    try std.testing.expectEqual(@as(?u32, KeySym.Alt_L), Modifier.toKeysym(Modifier.ALT));
    try std.testing.expectEqual(@as(?u32, null), Modifier.toKeysym(0));
}

test "KeyboardState: modifier tracking" {
    var state = KeyboardState{};

    // Initially no modifiers held
    try std.testing.expect(!state.isModifierHeld(Modifier.SHIFT));
    try std.testing.expect(!state.isModifierHeld(Modifier.CTRL));

    // Set Shift held
    state.setModifierHeld(Modifier.SHIFT, true);
    try std.testing.expect(state.isModifierHeld(Modifier.SHIFT));
    try std.testing.expect(!state.isModifierHeld(Modifier.CTRL));

    // Set Ctrl held
    state.setModifierHeld(Modifier.CTRL, true);
    try std.testing.expect(state.isModifierHeld(Modifier.SHIFT));
    try std.testing.expect(state.isModifierHeld(Modifier.CTRL));

    // Release Shift
    state.setModifierHeld(Modifier.SHIFT, false);
    try std.testing.expect(!state.isModifierHeld(Modifier.SHIFT));
    try std.testing.expect(state.isModifierHeld(Modifier.CTRL));
}

test "isShiftedChar: common shifted characters" {
    try std.testing.expectEqual(@as(?u32, '1'), isShiftedChar('!'));
    try std.testing.expectEqual(@as(?u32, '2'), isShiftedChar('@'));
    try std.testing.expectEqual(@as(?u32, '9'), isShiftedChar('('));
    try std.testing.expectEqual(@as(?u32, '0'), isShiftedChar(')'));
    try std.testing.expectEqual(@as(?u32, null), isShiftedChar('a'));
    try std.testing.expectEqual(@as(?u32, null), isShiftedChar('1'));
}

test "Keyboard.typeChar: would work with display" {
    // Skip if no display available
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        return;
    }

    // This test verifies the code path works
    // Actual typing would require a focused window
    Keyboard.typeChar('a') catch |err| {
        if (err == error.XTestNotAvailable or err == error.DisplayOpenFailed) {
            return;
        }
        // InvalidKeysym might occur if keyboard layout doesn't support the character
        if (err == error.InvalidCharacter) {
            return;
        }
        return err;
    };
}
