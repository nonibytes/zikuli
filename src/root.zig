//! Zikuli - Visual GUI Automation Library for Zig
//!
//! A faithful re-implementation of SikuliX in idiomatic Zig.
//! Provides image-based visual automation for GUI testing and scripting.
//!
//! ## Features
//! - Screen capture via X11/XCB
//! - Image pattern matching via OpenCV
//! - Mouse and keyboard control via XTest
//! - OCR text recognition via Tesseract
//!
//! ## Example Usage
//! ```zig
//! const zikuli = @import("zikuli");
//!
//! pub fn main() !void {
//!     var screen = try zikuli.Screen.primary();
//!     defer screen.deinit();
//!
//!     const match = try screen.region().find("button.png");
//!     try match.click();
//! }
//! ```

const std = @import("std");

// Version information
pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};

pub const version_string = "0.1.0";

// Re-export core modules (will be added in later phases)
// pub const geometry = @import("geometry.zig");
// pub const screen = @import("screen.zig");
// pub const image = @import("image.zig");
// pub const finder = @import("finder.zig");
// pub const mouse = @import("input/mouse.zig");
// pub const keyboard = @import("input/keyboard.zig");
// pub const region = @import("region.zig");
// pub const ocr = @import("ocr.zig");

// Convenience re-exports (will be added in later phases)
// pub const Point = geometry.Point;
// pub const Rectangle = geometry.Rectangle;
// pub const Region = region.Region;
// pub const Screen = screen.Screen;
// pub const Match = match.Match;
// pub const Pattern = pattern.Pattern;
// pub const Image = image.Image;
// pub const Mouse = mouse.Mouse;
// pub const Keyboard = keyboard.Keyboard;

/// Default minimum similarity threshold for image matching (like Sikuli's Settings.MinSimilarity)
pub const default_min_similarity: f64 = 0.7;

/// Default auto-wait timeout in seconds
pub const default_auto_wait_timeout: f64 = 3.0;

/// Placeholder function to verify library loads correctly
pub fn getVersion() []const u8 {
    return version_string;
}

test "version info" {
    try std.testing.expectEqual(@as(u16, 0), version.major);
    try std.testing.expectEqual(@as(u16, 1), version.minor);
    try std.testing.expectEqual(@as(u16, 0), version.patch);
    try std.testing.expectEqualStrings("0.1.0", getVersion());
}

test "default constants" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), default_min_similarity, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), default_auto_wait_timeout, 0.001);
}
