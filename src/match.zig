//! Match type for Zikuli
//!
//! A Match represents the result of a find operation - where a pattern
//! was found on screen, its similarity score, and timing information.
//!
//! Based on SikuliX Match.java analysis:
//! - Match extends Region (has bounds)
//! - Contains similarity score (0.0-1.0)
//! - Contains target offset for click location
//! - Contains optional OCR text result
//! - Contains timing information for profiling

const std = @import("std");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Location = geometry.Location;
const Rectangle = geometry.Rectangle;

/// A Match represents the result of a successful find operation
pub const Match = struct {
    /// The bounding rectangle of the match
    bounds: Rectangle,

    /// Similarity score (0.0 = no match, 1.0 = exact match)
    score: f64,

    /// Optional target offset from center (for click targeting)
    target_offset: ?Point,

    /// Text found by OCR (empty if not a text match)
    ocr_text: []const u8,

    /// Time spent searching (microseconds)
    search_time_us: i64,

    /// Time spent in find operation (microseconds)
    find_time_us: i64,

    /// Index in multi-match results (for findAll)
    index: i32,

    /// Whether match is on actual screen (vs. in-memory image)
    on_screen: bool,

    /// Image path used for matching (optional reference)
    image_path: []const u8,

    /// Create a basic match from bounds and score
    pub fn init(bounds: Rectangle, score: f64) Match {
        return .{
            .bounds = bounds,
            .score = score,
            .target_offset = null,
            .ocr_text = "",
            .search_time_us = -1,
            .find_time_us = -1,
            .index = -1,
            .on_screen = true,
            .image_path = "",
        };
    }

    /// Create match with position and size
    pub fn initAt(pos_x: i32, pos_y: i32, w: u32, h: u32, score: f64) Match {
        return init(Rectangle.init(pos_x, pos_y, w, h), score);
    }

    /// Create match for OCR text result
    pub fn initText(bounds: Rectangle, confidence: f64, text: []const u8) Match {
        return .{
            .bounds = bounds,
            .score = confidence,
            .target_offset = null,
            .ocr_text = text,
            .search_time_us = -1,
            .find_time_us = -1,
            .index = -1,
            .on_screen = true,
            .image_path = "",
        };
    }

    /// Get the center point of the match
    pub fn center(self: Match) Point {
        return self.bounds.center();
    }

    /// Get the center as floating-point location
    pub fn centerLocation(self: Match) Location {
        return self.bounds.centerLocation();
    }

    /// Get the click target (center + offset, or just center if no offset)
    pub fn getTarget(self: Match) Point {
        if (self.target_offset) |offset| {
            return self.center().offset(offset.x, offset.y);
        }
        return self.center();
    }

    /// Get the click target as floating-point location
    pub fn getTargetLocation(self: Match) Location {
        const c = self.centerLocation();
        if (self.target_offset) |offset| {
            return c.offset(@floatFromInt(offset.x), @floatFromInt(offset.y));
        }
        return c;
    }

    /// Set target offset relative to center
    pub fn setTargetOffset(self: *Match, dx: i32, dy: i32) void {
        self.target_offset = Point.init(dx, dy);
    }

    /// Get target offset (returns ORIGIN if none set)
    pub fn getTargetOffset(self: Match) Point {
        return self.target_offset orelse Point.ORIGIN;
    }

    /// Set timing information
    pub fn setTimes(self: *Match, find_time_us: i64, search_time_us: i64) void {
        self.find_time_us = find_time_us;
        self.search_time_us = search_time_us;
    }

    /// Get find time in milliseconds
    pub fn getTimeMs(self: Match) i64 {
        if (self.find_time_us < 0) return -1;
        return @divFloor(self.find_time_us, 1000);
    }

    /// Check if this is a text match (from OCR)
    pub fn isTextMatch(self: Match) bool {
        return self.ocr_text.len > 0;
    }

    /// Check if score meets threshold
    pub fn meetsThreshold(self: Match, threshold: f64) bool {
        return self.score >= threshold;
    }

    /// Get x coordinate
    pub fn x(self: Match) i32 {
        return self.bounds.x;
    }

    /// Get y coordinate
    pub fn y(self: Match) i32 {
        return self.bounds.y;
    }

    /// Get width
    pub fn width(self: Match) u32 {
        return self.bounds.width;
    }

    /// Get height
    pub fn height(self: Match) u32 {
        return self.bounds.height;
    }

    /// Compare matches (for sorting)
    /// Order: by score descending, then by position (x, y)
    pub fn compare(self: Match, other: Match) std.math.Order {
        // Compare by score first (higher is better, so reverse order)
        if (self.score != other.score) {
            if (self.score < other.score) return .gt; // other is better
            return .lt; // self is better
        }
        // Then by x position
        if (self.bounds.x != other.bounds.x) {
            return std.math.order(self.bounds.x, other.bounds.x);
        }
        // Then by y position
        if (self.bounds.y != other.bounds.y) {
            return std.math.order(self.bounds.y, other.bounds.y);
        }
        // Then by width
        if (self.bounds.width != other.bounds.width) {
            return std.math.order(self.bounds.width, other.bounds.width);
        }
        // Then by height
        return std.math.order(self.bounds.height, other.bounds.height);
    }

    /// Check equality (within tolerance for score)
    pub fn eql(self: Match, other: Match) bool {
        const score_tolerance = 1e-5;
        return self.bounds.eql(other.bounds) and
            @abs(self.score - other.score) < score_tolerance and
            self.getTarget().eql(other.getTarget());
    }

    pub fn format(
        self: Match,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        const target = self.getTarget();
        const center_pt = self.center();

        try writer.print("Match[{d},{d} {d}x{d}] S:{d:.2}", .{
            self.bounds.x,
            self.bounds.y,
            self.bounds.width,
            self.bounds.height,
            self.score,
        });

        if (!target.eql(center_pt)) {
            try writer.print(" T:{d},{d}", .{ target.x, target.y });
        } else {
            try writer.print(" C:{d},{d}", .{ center_pt.x, center_pt.y });
        }

        if (self.find_time_us >= 0) {
            try writer.print(" [{d}ms]", .{self.getTimeMs()});
        }
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Match: basic construction" {
    const m = Match.init(Rectangle.init(100, 200, 50, 30), 0.95);
    try std.testing.expectEqual(@as(i32, 100), m.x());
    try std.testing.expectEqual(@as(i32, 200), m.y());
    try std.testing.expectEqual(@as(u32, 50), m.width());
    try std.testing.expectEqual(@as(u32, 30), m.height());
    try std.testing.expectApproxEqAbs(@as(f64, 0.95), m.score, 0.0001);
    try std.testing.expect(m.on_screen);
}

test "Match: initAt convenience" {
    const m = Match.initAt(10, 20, 100, 50, 0.87);
    try std.testing.expectEqual(@as(i32, 10), m.x());
    try std.testing.expectEqual(@as(i32, 20), m.y());
    try std.testing.expectApproxEqAbs(@as(f64, 0.87), m.score, 0.0001);
}

test "Match: center calculation" {
    const m = Match.initAt(100, 200, 50, 30, 0.9);
    const c = m.center();
    try std.testing.expectEqual(@as(i32, 125), c.x);
    try std.testing.expectEqual(@as(i32, 215), c.y);
}

test "Match: target without offset" {
    const m = Match.initAt(100, 200, 50, 30, 0.9);
    const t = m.getTarget();
    const c = m.center();
    try std.testing.expect(t.eql(c));
}

test "Match: target with offset" {
    var m = Match.initAt(100, 200, 50, 30, 0.9);
    m.setTargetOffset(10, -5);

    const t = m.getTarget();
    try std.testing.expectEqual(@as(i32, 135), t.x); // 125 + 10
    try std.testing.expectEqual(@as(i32, 210), t.y); // 215 - 5
}

test "Match: getTargetOffset" {
    var m = Match.initAt(100, 200, 50, 30, 0.9);

    // No offset set
    const offset1 = m.getTargetOffset();
    try std.testing.expect(offset1.eql(Point.ORIGIN));

    // With offset
    m.setTargetOffset(10, -5);
    const offset2 = m.getTargetOffset();
    try std.testing.expectEqual(@as(i32, 10), offset2.x);
    try std.testing.expectEqual(@as(i32, -5), offset2.y);
}

test "Match: text match" {
    const m = Match.initText(Rectangle.init(50, 100, 200, 30), 0.92, "Hello World");
    try std.testing.expect(m.isTextMatch());
    try std.testing.expectEqualStrings("Hello World", m.ocr_text);
    try std.testing.expectApproxEqAbs(@as(f64, 0.92), m.score, 0.0001);
}

test "Match: non-text match" {
    const m = Match.initAt(100, 200, 50, 30, 0.9);
    try std.testing.expect(!m.isTextMatch());
}

test "Match: timing information" {
    var m = Match.initAt(100, 200, 50, 30, 0.9);

    // Initially no timing
    try std.testing.expectEqual(@as(i64, -1), m.getTimeMs());

    // Set timing
    m.setTimes(5000, 3000); // 5ms find, 3ms search
    try std.testing.expectEqual(@as(i64, 5), m.getTimeMs());
    try std.testing.expectEqual(@as(i64, 5000), m.find_time_us);
    try std.testing.expectEqual(@as(i64, 3000), m.search_time_us);
}

test "Match: meetsThreshold" {
    const m = Match.initAt(100, 200, 50, 30, 0.85);

    try std.testing.expect(m.meetsThreshold(0.7));
    try std.testing.expect(m.meetsThreshold(0.85));
    try std.testing.expect(!m.meetsThreshold(0.9));
}

test "Match: compare - by score" {
    const m1 = Match.initAt(0, 0, 10, 10, 0.95);
    const m2 = Match.initAt(0, 0, 10, 10, 0.85);

    // m1 has higher score, should come first (.lt)
    try std.testing.expectEqual(std.math.Order.lt, m1.compare(m2));
    try std.testing.expectEqual(std.math.Order.gt, m2.compare(m1));
}

test "Match: compare - same score, by position" {
    const m1 = Match.initAt(10, 20, 50, 30, 0.9);
    const m2 = Match.initAt(20, 20, 50, 30, 0.9);
    const m3 = Match.initAt(10, 30, 50, 30, 0.9);

    // Same score, m1 x < m2 x
    try std.testing.expectEqual(std.math.Order.lt, m1.compare(m2));

    // Same score and x, m1 y < m3 y
    try std.testing.expectEqual(std.math.Order.lt, m1.compare(m3));
}

test "Match: equality" {
    const m1 = Match.initAt(100, 200, 50, 30, 0.95);
    const m2 = Match.initAt(100, 200, 50, 30, 0.95);
    const m3 = Match.initAt(100, 200, 50, 30, 0.85);
    const m4 = Match.initAt(110, 200, 50, 30, 0.95);

    try std.testing.expect(m1.eql(m2));
    try std.testing.expect(!m1.eql(m3)); // Different score
    try std.testing.expect(!m1.eql(m4)); // Different position
}

test "Match: equality with offset" {
    var m1 = Match.initAt(100, 200, 50, 30, 0.95);
    var m2 = Match.initAt(100, 200, 50, 30, 0.95);

    m1.setTargetOffset(10, 5);
    try std.testing.expect(!m1.eql(m2)); // m2 has no offset

    m2.setTargetOffset(10, 5);
    try std.testing.expect(m1.eql(m2)); // Same offset
}

test "Match: index for findAll" {
    var m = Match.initAt(100, 200, 50, 30, 0.9);
    try std.testing.expectEqual(@as(i32, -1), m.index);

    m.index = 0;
    try std.testing.expectEqual(@as(i32, 0), m.index);
}

test "Match: negative coordinates" {
    const m = Match.initAt(-50, -100, 200, 150, 0.88);
    try std.testing.expectEqual(@as(i32, -50), m.x());
    try std.testing.expectEqual(@as(i32, -100), m.y());

    const c = m.center();
    try std.testing.expectEqual(@as(i32, 50), c.x); // -50 + 100
    try std.testing.expectEqual(@as(i32, -25), c.y); // -100 + 75
}

test "Match: score edge cases" {
    // Minimum score
    const m1 = Match.initAt(0, 0, 10, 10, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), m1.score, 0.0001);

    // Maximum score
    const m2 = Match.initAt(0, 0, 10, 10, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), m2.score, 0.0001);
}

test "Match: 1x1 pixel match" {
    const m = Match.initAt(500, 300, 1, 1, 0.99);
    try std.testing.expectEqual(@as(u32, 1), m.width());
    try std.testing.expectEqual(@as(u32, 1), m.height());

    const c = m.center();
    try std.testing.expectEqual(@as(i32, 500), c.x);
    try std.testing.expectEqual(@as(i32, 300), c.y);
}
