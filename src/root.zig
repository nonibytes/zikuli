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

// ============================================================================
// Core Modules (Phase 1)
// ============================================================================

pub const geometry = @import("geometry.zig");
pub const pattern = @import("pattern.zig");
pub const match = @import("match.zig");
pub const region = @import("region.zig");
pub const finder = @import("finder.zig");

// ============================================================================
// Platform Modules (Phase 2)
// ============================================================================

pub const x11 = @import("platform/x11.zig");
pub const platform_xtest = @import("platform/xtest.zig");
pub const screen = @import("screen.zig");
pub const image = @import("image.zig");

// Re-export Screen and Image
pub const Screen = screen.Screen;
pub const Image = image.Image;
pub const Finder = finder.Finder;

// Convenience re-exports - Core Types
pub const Point = geometry.Point;
pub const Location = geometry.Location;
pub const Rectangle = geometry.Rectangle;
pub const Pattern = pattern.Pattern;
pub const Match = match.Match;
pub const Region = region.Region;

// ============================================================================
// Input Modules (Phase 5)
// ============================================================================

pub const xtest = @import("xtest.zig");

// Re-export XTest types
pub const Mouse = xtest.Mouse;
pub const MouseButton = xtest.MouseButton;
pub const MouseState = xtest.MouseState;

// ============================================================================
// Modules to be added in later phases
// ============================================================================

// Phase 6: Keyboard control
// pub const keyboard = @import("input/keyboard.zig");
// pub const Keyboard = keyboard.Keyboard;

// Phase 8: OCR
// pub const ocr = @import("ocr.zig");
// pub const OCR = ocr.OCR;

// ============================================================================
// Constants (matching SikuliX Settings)
// ============================================================================

/// Default minimum similarity threshold for image matching
/// From SikuliX Settings.java:42: MinSimilarity = 0.7
pub const default_min_similarity: f64 = 0.7;

/// Default auto-wait timeout in seconds
/// From SikuliX Settings.java: AutoWaitTimeout = 3.0
pub const default_auto_wait_timeout: f64 = 3.0;

/// Minimum target dimension for pyramid matching
/// From finder.h:11: MIN_TARGET_DIMENSION = 12
pub const min_target_dimension: u32 = 12;

/// Threshold for re-matching in pyramid algorithm
/// From finder.h:15: REMATCH_THRESHOLD = 0.9
pub const rematch_threshold: f64 = 0.9;

/// Standard deviation threshold for plain color detection
/// From pyramid-template-matcher.h:64: stddev < 1e-5 = plain color
pub const plain_color_stddev: f64 = 1e-5;

// ============================================================================
// Public API Functions
// ============================================================================

/// Get library version string
pub fn getVersion() []const u8 {
    return version_string;
}

// ============================================================================
// Tests
// ============================================================================

test "version info" {
    try std.testing.expectEqual(@as(u16, 0), version.major);
    try std.testing.expectEqual(@as(u16, 1), version.minor);
    try std.testing.expectEqual(@as(u16, 0), version.patch);
    try std.testing.expectEqualStrings("0.1.0", getVersion());
}

test "default constants" {
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), default_min_similarity, 0.001);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), default_auto_wait_timeout, 0.001);
    try std.testing.expectEqual(@as(u32, 12), min_target_dimension);
}

// Reference tests from sub-modules to ensure they run
test {
    std.testing.refAllDecls(@This());
    _ = geometry;
    _ = pattern;
    _ = match;
    _ = region;
    _ = x11;
    _ = platform_xtest;
    _ = screen;
    _ = image;
    _ = xtest;
}
