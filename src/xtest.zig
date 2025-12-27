//! XTest - Synthetic input via XTest extension
//!
//! Provides mouse and keyboard control using the X11 XTest extension.
//! Based on SikuliX RobotDesktop.java analysis:
//! - Uses XTest for synthetic mouse events
//! - Smooth movement with quartic easing (AnimatorOutQuarticEase)
//! - Button state tracking for held buttons
//! - Position verification after movement
//!
//! XTest extension API:
//! - XTestFakeMotionEvent for mouse movement
//! - XTestFakeButtonEvent for button press/release
//! - XTestFakeKeyEvent for key press/release

const std = @import("std");
const geometry = @import("geometry.zig");
const platform_xtest = @import("platform/xtest.zig");
const Point = geometry.Point;
const XTestConnection = platform_xtest.XTestConnection;

/// Default smooth movement duration (from SikuliX Settings.MoveMouseDelay)
pub const DEFAULT_MOVE_DELAY_MS: u64 = 500;

/// Default click delay (from SikuliX Settings.ClickDelay)
pub const DEFAULT_CLICK_DELAY_MS: u64 = 0;

/// Wheel step delay (from SikuliX Mouse.WHEEL_STEP_DELAY)
pub const WHEEL_STEP_DELAY_MS: u64 = 50;

/// Mouse button constants (from SikuliX Mouse.java, matching java.awt.InputEvent)
pub const MouseButton = enum(u32) {
    left = 1, // XTest button 1
    middle = 2, // XTest button 2
    right = 3, // XTest button 3

    // Wheel buttons (4=up, 5=down in X11)
    wheel_up = 4,
    wheel_down = 5,
};

/// Mouse state for tracking held buttons
pub const MouseState = struct {
    held_buttons: u32 = 0,
    last_pos: ?Point = null,

    pub fn isButtonHeld(self: MouseState, button: MouseButton) bool {
        const shift: u5 = @intCast(@intFromEnum(button));
        const mask = @as(u32, 1) << shift;
        return (self.held_buttons & mask) != 0;
    }

    pub fn setButtonHeld(self: *MouseState, button: MouseButton, held: bool) void {
        const shift: u5 = @intCast(@intFromEnum(button));
        const mask = @as(u32, 1) << shift;
        if (held) {
            self.held_buttons |= mask;
        } else {
            self.held_buttons &= ~mask;
        }
    }
};

/// Global mouse state
var global_state: MouseState = .{};

/// Global XTest connection (lazy initialized)
var global_connection: ?XTestConnection = null;

/// Get or create the global XTest connection
fn getConnection() !*XTestConnection {
    if (global_connection == null) {
        global_connection = XTestConnection.connectDefault() catch |err| {
            return err;
        };
    }
    return &global_connection.?;
}

/// Clean up the global connection
pub fn deinit() void {
    if (global_connection) |*conn| {
        conn.disconnect();
        global_connection = null;
    }
}

/// XTest mouse controller
/// Provides a static API for mouse control using the X11 XTest extension.
pub const Mouse = struct {
    /// Move mouse to absolute position (instant)
    pub fn moveTo(x: i32, y: i32) !void {
        const conn = try getConnection();
        try conn.moveMouse(x, y);
        global_state.last_pos = Point.init(x, y);
    }

    /// Move mouse to position with smooth animation
    /// Uses quartic easing (fast start, slow end) like SikuliX
    pub fn smoothMove(dest_x: i32, dest_y: i32, duration_ms: u64) !void {
        const conn = try getConnection();

        // Get current position
        const start_pos = try conn.getMousePosition();

        if (duration_ms == 0) {
            // Instant move
            try conn.moveMouse(dest_x, dest_y);
            global_state.last_pos = Point.init(dest_x, dest_y);
            return;
        }

        // Animate using quartic easing
        const start_x: f64 = @floatFromInt(start_pos.x);
        const start_y: f64 = @floatFromInt(start_pos.y);
        const end_x: f64 = @floatFromInt(dest_x);
        const end_y: f64 = @floatFromInt(dest_y);

        const start_time = std.time.nanoTimestamp();
        const duration_ns: i128 = @as(i128, @intCast(duration_ms)) * std.time.ns_per_ms;

        while (true) {
            const elapsed_ns = std.time.nanoTimestamp() - start_time;
            if (elapsed_ns >= duration_ns) break;

            const t: f64 = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(duration_ns));
            const x = quarticEaseOut(t, start_x, end_x);
            const y = quarticEaseOut(t, start_y, end_y);

            try conn.moveMouse(@intFromFloat(x), @intFromFloat(y));

            // Small sleep to avoid overwhelming X server
            std.Thread.sleep(std.time.ns_per_ms);
        }

        // Ensure we end exactly at destination
        try conn.moveMouse(dest_x, dest_y);
        global_state.last_pos = Point.init(dest_x, dest_y);
    }

    /// Move with default smooth animation
    pub fn smoothMoveTo(dest_x: i32, dest_y: i32) !void {
        return smoothMove(dest_x, dest_y, DEFAULT_MOVE_DELAY_MS);
    }

    /// Get current mouse position
    pub fn getPosition() !Point {
        const conn = try getConnection();
        return conn.getMousePosition();
    }

    /// Press a mouse button
    pub fn buttonDown(button: MouseButton) !void {
        const conn = try getConnection();
        try conn.mouseDown(@intFromEnum(button));
        global_state.setButtonHeld(button, true);
    }

    /// Release a mouse button
    pub fn buttonUp(button: MouseButton) !void {
        const conn = try getConnection();
        try conn.mouseUp(@intFromEnum(button));
        global_state.setButtonHeld(button, false);
    }

    /// Click (press and release)
    pub fn click(button: MouseButton) !void {
        try buttonDown(button);
        if (DEFAULT_CLICK_DELAY_MS > 0) {
            std.Thread.sleep(DEFAULT_CLICK_DELAY_MS * std.time.ns_per_ms);
        }
        try buttonUp(button);
    }

    /// Left click (convenience)
    pub fn leftClick() !void {
        return click(.left);
    }

    /// Right click (convenience)
    pub fn rightClick() !void {
        return click(.right);
    }

    /// Middle click (convenience)
    pub fn middleClick() !void {
        return click(.middle);
    }

    /// Double click
    pub fn doubleClick(button: MouseButton) !void {
        try click(button);
        std.Thread.sleep(50 * std.time.ns_per_ms);
        try click(button);
    }

    /// Double left click (convenience)
    pub fn doubleLeftClick() !void {
        return doubleClick(.left);
    }

    /// Scroll wheel
    /// direction: .wheel_up or .wheel_down
    /// steps: number of scroll steps
    pub fn wheel(direction: MouseButton, steps: u32) !void {
        if (direction != .wheel_up and direction != .wheel_down) {
            return error.InvalidWheelDirection;
        }

        const conn = try getConnection();
        var i: u32 = 0;
        while (i < steps) : (i += 1) {
            try conn.mouseClick(@intFromEnum(direction));
            if (i + 1 < steps) {
                std.Thread.sleep(WHEEL_STEP_DELAY_MS * std.time.ns_per_ms);
            }
        }
    }

    /// Scroll up
    pub fn wheelUp(steps: u32) !void {
        return wheel(.wheel_up, steps);
    }

    /// Scroll down
    pub fn wheelDown(steps: u32) !void {
        return wheel(.wheel_down, steps);
    }

    /// Click at a specific position
    pub fn clickAt(x: i32, y: i32, button: MouseButton) !void {
        try smoothMoveTo(x, y);
        try click(button);
    }

    /// Drag from current position to destination
    pub fn drag(dest_x: i32, dest_y: i32, button: MouseButton) !void {
        try buttonDown(button);
        try smoothMoveTo(dest_x, dest_y);
        try buttonUp(button);
    }

    /// Drag from one position to another
    pub fn dragFromTo(src_x: i32, src_y: i32, dest_x: i32, dest_y: i32, button: MouseButton) !void {
        try smoothMoveTo(src_x, src_y);
        try drag(dest_x, dest_y, button);
    }

    /// Get current mouse state
    pub fn getState() MouseState {
        return global_state;
    }

    /// Reset mouse state (release all held buttons)
    pub fn reset() !void {
        const conn = try getConnection();

        // Release all held buttons
        inline for ([_]MouseButton{ .left, .middle, .right }) |btn| {
            if (global_state.isButtonHeld(btn)) {
                try conn.mouseUp(@intFromEnum(btn));
            }
        }
        global_state.held_buttons = 0;
    }
};

/// Quartic easing out: fast start, slow end
/// Formula from SikuliX AnimatorOutQuarticEase.java:
/// value(t) = beginVal + (endVal - beginVal) * (-1 * t^4 + 4 * t^3 - 6 * t^2 + 4 * t)
/// where t is normalized time [0, 1]
pub fn quarticEaseOut(t: f64, start: f64, end: f64) f64 {
    // Clamp t to [0, 1]
    const t1 = std.math.clamp(t, 0.0, 1.0);
    const t2 = t1 * t1;
    const t3 = t1 * t2;
    const t4 = t2 * t2;

    // SikuliX formula: -t^4 + 4t^3 - 6t^2 + 4t
    const easing = -t4 + 4.0 * t3 - 6.0 * t2 + 4.0 * t1;

    return start + (end - start) * easing;
}

// ============================================================================
// Error types
// ============================================================================

pub const MouseError = error{
    InvalidWheelDirection,
};

// ============================================================================
// TESTS
// ============================================================================

test "quarticEaseOut: boundary values" {
    // At t=0, should return start value
    const start = quarticEaseOut(0.0, 100.0, 200.0);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), start, 0.001);

    // At t=1, should return end value
    const end = quarticEaseOut(1.0, 100.0, 200.0);
    try std.testing.expectApproxEqAbs(@as(f64, 200.0), end, 0.001);
}

test "quarticEaseOut: midpoint check" {
    // At t=0.5, the easing should be past the midpoint (fast start)
    const mid = quarticEaseOut(0.5, 0.0, 100.0);
    // Formula: -0.0625 + 0.5 - 1.5 + 2 = 0.9375
    // So value should be about 93.75
    try std.testing.expect(mid > 90.0); // Past 90% at halfway through time
}

test "quarticEaseOut: monotonic increase" {
    // The function should be monotonically increasing
    var prev: f64 = 0.0;
    var t: f64 = 0.0;
    while (t <= 1.0) : (t += 0.1) {
        const val = quarticEaseOut(t, 0.0, 100.0);
        try std.testing.expect(val >= prev);
        prev = val;
    }
}

test "Mouse.getPosition: returns current position" {
    // Skip if no display available
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        return;
    }

    const pos = Mouse.getPosition() catch |err| {
        // XTest might not be available
        if (err == error.XTestNotAvailable or err == error.DisplayOpenFailed) {
            return;
        }
        return err;
    };

    // If we get here, position was returned - verify it's within reasonable bounds
    try std.testing.expect(pos.x >= 0);
    try std.testing.expect(pos.y >= 0);
    try std.testing.expect(pos.x < 10000);
    try std.testing.expect(pos.y < 10000);
}

test "Mouse.moveTo: moves to specified position" {
    // Skip if no display available
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        return;
    }

    const target_x: i32 = 500;
    const target_y: i32 = 300;

    Mouse.moveTo(target_x, target_y) catch |err| {
        if (err == error.XTestNotAvailable or err == error.DisplayOpenFailed) {
            return;
        }
        return err;
    };

    // Verify position after move
    const pos = try Mouse.getPosition();
    try std.testing.expect(@abs(pos.x - target_x) <= 2);
    try std.testing.expect(@abs(pos.y - target_y) <= 2);
}

test "MouseButton: correct values" {
    // X11 button numbers
    try std.testing.expectEqual(@as(u32, 1), @intFromEnum(MouseButton.left));
    try std.testing.expectEqual(@as(u32, 2), @intFromEnum(MouseButton.middle));
    try std.testing.expectEqual(@as(u32, 3), @intFromEnum(MouseButton.right));
    try std.testing.expectEqual(@as(u32, 4), @intFromEnum(MouseButton.wheel_up));
    try std.testing.expectEqual(@as(u32, 5), @intFromEnum(MouseButton.wheel_down));
}

test "MouseState: button tracking" {
    var state = MouseState{};

    // Initially no buttons held
    try std.testing.expect(!state.isButtonHeld(.left));
    try std.testing.expect(!state.isButtonHeld(.right));

    // Set left button held
    state.setButtonHeld(.left, true);
    try std.testing.expect(state.isButtonHeld(.left));
    try std.testing.expect(!state.isButtonHeld(.right));

    // Release left button
    state.setButtonHeld(.left, false);
    try std.testing.expect(!state.isButtonHeld(.left));
}

test "Mouse constants" {
    try std.testing.expectEqual(@as(u64, 500), DEFAULT_MOVE_DELAY_MS);
    try std.testing.expectEqual(@as(u64, 50), WHEEL_STEP_DELAY_MS);
}
