//! Pattern type for Zikuli
//!
//! A Pattern represents a search target: an image to find on screen
//! with optional similarity threshold and click offset.

const std = @import("std");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Location = geometry.Location;

/// Default minimum similarity threshold (from SikuliX Settings.java:42)
pub const DEFAULT_SIMILARITY: f64 = 0.7;

/// Minimum allowed similarity (matching anything lower is meaningless)
pub const MIN_SIMILARITY: f64 = 0.5;

/// Maximum similarity (exact match)
pub const MAX_SIMILARITY: f64 = 1.0;

/// A Pattern represents an image to search for with matching parameters
pub const Pattern = struct {
    /// Path to the image file (or image identifier)
    image_path: []const u8,

    /// Minimum similarity score for a match (0.0 to 1.0)
    similarity: f64,

    /// Offset from match center for click target
    target_offset: Point,

    /// Whether this is a text pattern (for OCR matching)
    is_text: bool,

    /// Create a pattern from an image path with default similarity
    pub fn init(image_path: []const u8) Pattern {
        return .{
            .image_path = image_path,
            .similarity = DEFAULT_SIMILARITY,
            .target_offset = Point.ORIGIN,
            .is_text = false,
        };
    }

    /// Create a pattern with custom similarity threshold
    pub fn withSimilarity(image_path: []const u8, similarity: f64) Pattern {
        return .{
            .image_path = image_path,
            .similarity = clampSimilarity(similarity),
            .target_offset = Point.ORIGIN,
            .is_text = false,
        };
    }

    /// Create a text pattern for OCR matching
    pub fn text(text_content: []const u8) Pattern {
        return .{
            .image_path = text_content,
            .similarity = DEFAULT_SIMILARITY,
            .target_offset = Point.ORIGIN,
            .is_text = true,
        };
    }

    /// Set similarity threshold (builder pattern)
    pub fn similar(self: Pattern, similarity: f64) Pattern {
        var result = self;
        result.similarity = clampSimilarity(similarity);
        return result;
    }

    /// Set exact match (similarity = 1.0)
    pub fn exact(self: Pattern) Pattern {
        var result = self;
        result.similarity = MAX_SIMILARITY;
        return result;
    }

    /// Set target offset from center (builder pattern)
    pub fn targetOffset(self: Pattern, dx: i32, dy: i32) Pattern {
        var result = self;
        result.target_offset = Point.init(dx, dy);
        return result;
    }

    /// Check if similarity threshold is valid
    pub fn isValidSimilarity(similarity: f64) bool {
        return similarity >= MIN_SIMILARITY and similarity <= MAX_SIMILARITY and !std.math.isNan(similarity);
    }

    /// Get the effective click location given a match location
    pub fn getClickTarget(self: Pattern, match_center: Point) Point {
        return match_center.offset(self.target_offset.x, self.target_offset.y);
    }

    /// Get the effective click location as floating point
    pub fn getClickTargetLocation(self: Pattern, match_center: Location) Location {
        return match_center.offset(
            @floatFromInt(self.target_offset.x),
            @floatFromInt(self.target_offset.y),
        );
    }

    /// Check if two patterns are equivalent
    pub fn eql(self: Pattern, other: Pattern) bool {
        return std.mem.eql(u8, self.image_path, other.image_path) and
            self.similarity == other.similarity and
            self.target_offset.eql(other.target_offset) and
            self.is_text == other.is_text;
    }

    pub fn format(
        self: Pattern,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        if (self.is_text) {
            try writer.print("Pattern(text=\"{s}\", sim={d:.2})", .{ self.image_path, self.similarity });
        } else {
            try writer.print("Pattern(\"{s}\", sim={d:.2})", .{ self.image_path, self.similarity });
        }
    }
};

/// Clamp similarity to valid range
fn clampSimilarity(similarity: f64) f64 {
    if (std.math.isNan(similarity)) return DEFAULT_SIMILARITY;
    return std.math.clamp(similarity, MIN_SIMILARITY, MAX_SIMILARITY);
}

// ============================================================================
// TESTS
// ============================================================================

test "Pattern: basic construction" {
    const p = Pattern.init("button.png");
    try std.testing.expectEqualStrings("button.png", p.image_path);
    try std.testing.expectApproxEqAbs(DEFAULT_SIMILARITY, p.similarity, 0.0001);
    try std.testing.expect(p.target_offset.eql(Point.ORIGIN));
    try std.testing.expect(!p.is_text);
}

test "Pattern: with custom similarity" {
    const p = Pattern.withSimilarity("icon.png", 0.9);
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), p.similarity, 0.0001);
}

test "Pattern: similarity clamping" {
    // Below minimum
    const p1 = Pattern.withSimilarity("test.png", 0.3);
    try std.testing.expectApproxEqAbs(MIN_SIMILARITY, p1.similarity, 0.0001);

    // Above maximum
    const p2 = Pattern.withSimilarity("test.png", 1.5);
    try std.testing.expectApproxEqAbs(MAX_SIMILARITY, p2.similarity, 0.0001);

    // NaN becomes default
    const p3 = Pattern.withSimilarity("test.png", std.math.nan(f64));
    try std.testing.expectApproxEqAbs(DEFAULT_SIMILARITY, p3.similarity, 0.0001);
}

test "Pattern: builder pattern - similar" {
    const p = Pattern.init("button.png").similar(0.95);
    try std.testing.expectApproxEqAbs(@as(f64, 0.95), p.similarity, 0.0001);
    try std.testing.expectEqualStrings("button.png", p.image_path);
}

test "Pattern: builder pattern - exact" {
    const p = Pattern.init("button.png").exact();
    try std.testing.expectApproxEqAbs(MAX_SIMILARITY, p.similarity, 0.0001);
}

test "Pattern: builder pattern - targetOffset" {
    const p = Pattern.init("button.png").targetOffset(10, -5);
    try std.testing.expectEqual(@as(i32, 10), p.target_offset.x);
    try std.testing.expectEqual(@as(i32, -5), p.target_offset.y);
}

test "Pattern: chained builders" {
    const p = Pattern.init("button.png")
        .similar(0.85)
        .targetOffset(20, 30);

    try std.testing.expectApproxEqAbs(@as(f64, 0.85), p.similarity, 0.0001);
    try std.testing.expectEqual(@as(i32, 20), p.target_offset.x);
    try std.testing.expectEqual(@as(i32, 30), p.target_offset.y);
}

test "Pattern: text pattern" {
    const p = Pattern.text("Submit");
    try std.testing.expect(p.is_text);
    try std.testing.expectEqualStrings("Submit", p.image_path);
}

test "Pattern: getClickTarget" {
    const p = Pattern.init("button.png").targetOffset(10, -5);
    const match_center = Point.init(100, 200);
    const target = p.getClickTarget(match_center);

    try std.testing.expectEqual(@as(i32, 110), target.x);
    try std.testing.expectEqual(@as(i32, 195), target.y);
}

test "Pattern: getClickTargetLocation" {
    const p = Pattern.init("button.png").targetOffset(10, -5);
    const match_center = Location.init(100.5, 200.5);
    const target = p.getClickTargetLocation(match_center);

    try std.testing.expectApproxEqAbs(@as(f64, 110.5), target.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 195.5), target.y, 0.0001);
}

test "Pattern: isValidSimilarity" {
    try std.testing.expect(Pattern.isValidSimilarity(0.7));
    try std.testing.expect(Pattern.isValidSimilarity(0.5));
    try std.testing.expect(Pattern.isValidSimilarity(1.0));

    try std.testing.expect(!Pattern.isValidSimilarity(0.4));
    try std.testing.expect(!Pattern.isValidSimilarity(1.1));
    try std.testing.expect(!Pattern.isValidSimilarity(std.math.nan(f64)));
}

test "Pattern: equality" {
    const p1 = Pattern.init("button.png").similar(0.8);
    const p2 = Pattern.init("button.png").similar(0.8);
    const p3 = Pattern.init("button.png").similar(0.9);
    const p4 = Pattern.init("other.png").similar(0.8);

    try std.testing.expect(p1.eql(p2));
    try std.testing.expect(!p1.eql(p3));
    try std.testing.expect(!p1.eql(p4));
}
