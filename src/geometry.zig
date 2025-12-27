//! Core geometry types for Zikuli
//!
//! Provides Point, Rectangle, and Location types for screen coordinates
//! and region definitions. All types are stack-allocated with no hidden
//! allocations following Zig philosophy.

const std = @import("std");

/// A 2D point with integer coordinates (screen pixels)
pub const Point = struct {
    x: i32,
    y: i32,

    pub const ORIGIN = Point{ .x = 0, .y = 0 };

    pub fn init(x: i32, y: i32) Point {
        return .{ .x = x, .y = y };
    }

    /// Offset point by delta values
    pub fn offset(self: Point, dx: i32, dy: i32) Point {
        return .{
            .x = self.x +| dx, // Saturating add to prevent overflow
            .y = self.y +| dy,
        };
    }

    /// Distance to another point (Euclidean)
    pub fn distanceTo(self: Point, other: Point) f64 {
        const dx: f64 = @floatFromInt(other.x - self.x);
        const dy: f64 = @floatFromInt(other.y - self.y);
        return @sqrt(dx * dx + dy * dy);
    }

    /// Manhattan distance to another point
    pub fn manhattanDistanceTo(self: Point, other: Point) u32 {
        const dx: u32 = @abs(other.x - self.x);
        const dy: u32 = @abs(other.y - self.y);
        return dx + dy;
    }

    /// Check equality
    pub fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }

    pub fn format(
        self: Point,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Point({d}, {d})", .{ self.x, self.y });
    }
};

/// A 2D point with floating-point coordinates (sub-pixel precision)
pub const Location = struct {
    x: f64,
    y: f64,

    pub const ORIGIN = Location{ .x = 0.0, .y = 0.0 };

    pub fn init(x: f64, y: f64) Location {
        return .{ .x = x, .y = y };
    }

    /// Create Location from Point
    pub fn fromPoint(p: Point) Location {
        return .{
            .x = @floatFromInt(p.x),
            .y = @floatFromInt(p.y),
        };
    }

    /// Convert to Point (rounds to nearest integer)
    pub fn toPoint(self: Location) Point {
        return .{
            .x = @intFromFloat(@round(self.x)),
            .y = @intFromFloat(@round(self.y)),
        };
    }

    /// Offset location by delta values
    pub fn offset(self: Location, dx: f64, dy: f64) Location {
        return .{ .x = self.x + dx, .y = self.y + dy };
    }

    /// Distance to another location
    pub fn distanceTo(self: Location, other: Location) f64 {
        const dx = other.x - self.x;
        const dy = other.y - self.y;
        return @sqrt(dx * dx + dy * dy);
    }

    /// Linear interpolation between two locations
    pub fn lerp(self: Location, other: Location, t: f64) Location {
        const clamped_t = std.math.clamp(t, 0.0, 1.0);
        return .{
            .x = self.x + (other.x - self.x) * clamped_t,
            .y = self.y + (other.y - self.y) * clamped_t,
        };
    }

    pub fn format(
        self: Location,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Location({d:.2}, {d:.2})", .{ self.x, self.y });
    }
};

/// A rectangle defined by position and size
pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: u32,
    height: u32,

    pub const EMPTY = Rectangle{ .x = 0, .y = 0, .width = 0, .height = 0 };

    pub fn init(x: i32, y: i32, width: u32, height: u32) Rectangle {
        return .{ .x = x, .y = y, .width = width, .height = height };
    }

    /// Create rectangle from two corner points
    pub fn fromPoints(p1: Point, p2: Point) Rectangle {
        const min_x = @min(p1.x, p2.x);
        const min_y = @min(p1.y, p2.y);
        const max_x = @max(p1.x, p2.x);
        const max_y = @max(p1.y, p2.y);
        return .{
            .x = min_x,
            .y = min_y,
            .width = @intCast(max_x - min_x),
            .height = @intCast(max_y - min_y),
        };
    }

    /// Get center point of rectangle
    pub fn center(self: Rectangle) Point {
        return .{
            .x = self.x +| @as(i32, @intCast(self.width / 2)),
            .y = self.y +| @as(i32, @intCast(self.height / 2)),
        };
    }

    /// Get center as floating-point location
    pub fn centerLocation(self: Rectangle) Location {
        return .{
            .x = @as(f64, @floatFromInt(self.x)) + @as(f64, @floatFromInt(self.width)) / 2.0,
            .y = @as(f64, @floatFromInt(self.y)) + @as(f64, @floatFromInt(self.height)) / 2.0,
        };
    }

    /// Get top-left corner
    pub fn topLeft(self: Rectangle) Point {
        return .{ .x = self.x, .y = self.y };
    }

    /// Get top-right corner
    pub fn topRight(self: Rectangle) Point {
        return .{ .x = self.x +| @as(i32, @intCast(self.width)), .y = self.y };
    }

    /// Get bottom-left corner
    pub fn bottomLeft(self: Rectangle) Point {
        return .{ .x = self.x, .y = self.y +| @as(i32, @intCast(self.height)) };
    }

    /// Get bottom-right corner
    pub fn bottomRight(self: Rectangle) Point {
        return .{
            .x = self.x +| @as(i32, @intCast(self.width)),
            .y = self.y +| @as(i32, @intCast(self.height)),
        };
    }

    /// Get right edge x-coordinate
    pub fn right(self: Rectangle) i32 {
        return self.x +| @as(i32, @intCast(self.width));
    }

    /// Get bottom edge y-coordinate
    pub fn bottom(self: Rectangle) i32 {
        return self.y +| @as(i32, @intCast(self.height));
    }

    /// Check if rectangle is empty (zero area)
    pub fn isEmpty(self: Rectangle) bool {
        return self.width == 0 or self.height == 0;
    }

    /// Get area of rectangle
    pub fn area(self: Rectangle) u64 {
        return @as(u64, self.width) * @as(u64, self.height);
    }

    /// Check if point is inside rectangle
    pub fn contains(self: Rectangle, p: Point) bool {
        return p.x >= self.x and
            p.x < self.x +| @as(i32, @intCast(self.width)) and
            p.y >= self.y and
            p.y < self.y +| @as(i32, @intCast(self.height));
    }

    /// Check if another rectangle is fully contained
    pub fn containsRect(self: Rectangle, other: Rectangle) bool {
        if (other.isEmpty()) return true;
        return other.x >= self.x and
            other.y >= self.y and
            other.right() <= self.right() and
            other.bottom() <= self.bottom();
    }

    /// Check if rectangles intersect
    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        if (self.isEmpty() or other.isEmpty()) return false;
        return !(other.x >= self.right() or
            other.right() <= self.x or
            other.y >= self.bottom() or
            other.bottom() <= self.y);
    }

    /// Get intersection of two rectangles
    pub fn intersection(self: Rectangle, other: Rectangle) Rectangle {
        if (!self.intersects(other)) return EMPTY;

        const new_x = @max(self.x, other.x);
        const new_y = @max(self.y, other.y);
        const new_right = @min(self.right(), other.right());
        const new_bottom = @min(self.bottom(), other.bottom());

        return .{
            .x = new_x,
            .y = new_y,
            .width = @intCast(new_right - new_x),
            .height = @intCast(new_bottom - new_y),
        };
    }

    /// Get bounding rectangle of two rectangles (union)
    pub fn boundingRect(self: Rectangle, other: Rectangle) Rectangle {
        if (self.isEmpty()) return other;
        if (other.isEmpty()) return self;

        const new_x = @min(self.x, other.x);
        const new_y = @min(self.y, other.y);
        const new_right = @max(self.right(), other.right());
        const new_bottom = @max(self.bottom(), other.bottom());

        return .{
            .x = new_x,
            .y = new_y,
            .width = @intCast(new_right - new_x),
            .height = @intCast(new_bottom - new_y),
        };
    }

    /// Expand rectangle by amount on all sides
    pub fn expand(self: Rectangle, amount: i32) Rectangle {
        const new_x = self.x -| amount;
        const new_y = self.y -| amount;
        const expansion: u32 = @intCast(@max(0, amount * 2));
        return .{
            .x = new_x,
            .y = new_y,
            .width = self.width +| expansion,
            .height = self.height +| expansion,
        };
    }

    /// Shrink rectangle by amount on all sides
    pub fn shrink(self: Rectangle, amount: u32) Rectangle {
        if (amount * 2 >= self.width or amount * 2 >= self.height) {
            return EMPTY;
        }
        return .{
            .x = self.x +| @as(i32, @intCast(amount)),
            .y = self.y +| @as(i32, @intCast(amount)),
            .width = self.width - amount * 2,
            .height = self.height - amount * 2,
        };
    }

    /// Offset rectangle position
    pub fn offset(self: Rectangle, dx: i32, dy: i32) Rectangle {
        return .{
            .x = self.x +| dx,
            .y = self.y +| dy,
            .width = self.width,
            .height = self.height,
        };
    }

    /// Check equality
    pub fn eql(self: Rectangle, other: Rectangle) bool {
        return self.x == other.x and
            self.y == other.y and
            self.width == other.width and
            self.height == other.height;
    }

    pub fn format(
        self: Rectangle,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Rect({d}, {d}, {d}x{d})", .{ self.x, self.y, self.width, self.height });
    }
};

// ============================================================================
// TESTS - Verification First Development
// ============================================================================

test "Point: basic construction and equality" {
    const p1 = Point.init(10, 20);
    const p2 = Point.init(10, 20);
    const p3 = Point.init(30, 40);

    try std.testing.expect(p1.eql(p2));
    try std.testing.expect(!p1.eql(p3));
    try std.testing.expect(Point.ORIGIN.eql(Point.init(0, 0)));
}

test "Point: offset arithmetic" {
    const p = Point.init(10, 20);

    // Normal offset
    const p2 = p.offset(5, -10);
    try std.testing.expectEqual(@as(i32, 15), p2.x);
    try std.testing.expectEqual(@as(i32, 10), p2.y);

    // Zero offset
    const p3 = p.offset(0, 0);
    try std.testing.expect(p.eql(p3));
}

test "Point: offset with overflow protection" {
    // Test saturating arithmetic at boundaries
    const max_point = Point.init(std.math.maxInt(i32), std.math.maxInt(i32));
    const overflow_result = max_point.offset(1, 1);
    try std.testing.expectEqual(std.math.maxInt(i32), overflow_result.x);
    try std.testing.expectEqual(std.math.maxInt(i32), overflow_result.y);

    const min_point = Point.init(std.math.minInt(i32), std.math.minInt(i32));
    const underflow_result = min_point.offset(-1, -1);
    try std.testing.expectEqual(std.math.minInt(i32), underflow_result.x);
    try std.testing.expectEqual(std.math.minInt(i32), underflow_result.y);
}

test "Point: negative coordinates" {
    const p = Point.init(-100, -200);
    try std.testing.expectEqual(@as(i32, -100), p.x);
    try std.testing.expectEqual(@as(i32, -200), p.y);

    const p2 = p.offset(-50, 300);
    try std.testing.expectEqual(@as(i32, -150), p2.x);
    try std.testing.expectEqual(@as(i32, 100), p2.y);
}

test "Point: distance calculations" {
    const p1 = Point.init(0, 0);
    const p2 = Point.init(3, 4);

    // Euclidean distance (3-4-5 triangle)
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), p1.distanceTo(p2), 0.0001);

    // Manhattan distance
    try std.testing.expectEqual(@as(u32, 7), p1.manhattanDistanceTo(p2));

    // Distance to self
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), p1.distanceTo(p1), 0.0001);
}

test "Location: construction and conversion" {
    const loc = Location.init(10.5, 20.7);
    try std.testing.expectApproxEqAbs(@as(f64, 10.5), loc.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 20.7), loc.y, 0.0001);

    // From point
    const p = Point.init(15, 25);
    const loc2 = Location.fromPoint(p);
    try std.testing.expectApproxEqAbs(@as(f64, 15.0), loc2.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 25.0), loc2.y, 0.0001);
}

test "Location: toPoint rounding" {
    // Round down
    const loc1 = Location.init(10.4, 20.4);
    const p1 = loc1.toPoint();
    try std.testing.expectEqual(@as(i32, 10), p1.x);
    try std.testing.expectEqual(@as(i32, 20), p1.y);

    // Round up
    const loc2 = Location.init(10.6, 20.6);
    const p2 = loc2.toPoint();
    try std.testing.expectEqual(@as(i32, 11), p2.x);
    try std.testing.expectEqual(@as(i32, 21), p2.y);

    // Exact half rounds to even (banker's rounding) or up
    const loc3 = Location.init(10.5, 20.5);
    const p3 = loc3.toPoint();
    try std.testing.expectEqual(@as(i32, 11), p3.x); // 10.5 rounds to 11
    try std.testing.expectEqual(@as(i32, 21), p3.y);
}

test "Location: lerp interpolation" {
    const start = Location.init(0.0, 0.0);
    const end = Location.init(100.0, 200.0);

    // Start point
    const l0 = start.lerp(end, 0.0);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), l0.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), l0.y, 0.0001);

    // End point
    const l1 = start.lerp(end, 1.0);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), l1.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 200.0), l1.y, 0.0001);

    // Mid point
    const l05 = start.lerp(end, 0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 50.0), l05.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), l05.y, 0.0001);

    // Clamp beyond range
    const l_over = start.lerp(end, 1.5);
    try std.testing.expectApproxEqAbs(@as(f64, 100.0), l_over.x, 0.0001);

    const l_under = start.lerp(end, -0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), l_under.x, 0.0001);
}

test "Rectangle: basic construction" {
    const r = Rectangle.init(10, 20, 100, 200);
    try std.testing.expectEqual(@as(i32, 10), r.x);
    try std.testing.expectEqual(@as(i32, 20), r.y);
    try std.testing.expectEqual(@as(u32, 100), r.width);
    try std.testing.expectEqual(@as(u32, 200), r.height);
}

test "Rectangle: from two points" {
    // Normal order
    const r1 = Rectangle.fromPoints(Point.init(10, 20), Point.init(110, 220));
    try std.testing.expectEqual(@as(i32, 10), r1.x);
    try std.testing.expectEqual(@as(i32, 20), r1.y);
    try std.testing.expectEqual(@as(u32, 100), r1.width);
    try std.testing.expectEqual(@as(u32, 200), r1.height);

    // Reversed order (should normalize)
    const r2 = Rectangle.fromPoints(Point.init(110, 220), Point.init(10, 20));
    try std.testing.expect(r1.eql(r2));
}

test "Rectangle: corner points" {
    const r = Rectangle.init(10, 20, 100, 200);

    try std.testing.expect(r.topLeft().eql(Point.init(10, 20)));
    try std.testing.expect(r.topRight().eql(Point.init(110, 20)));
    try std.testing.expect(r.bottomLeft().eql(Point.init(10, 220)));
    try std.testing.expect(r.bottomRight().eql(Point.init(110, 220)));
}

test "Rectangle: center calculation" {
    const r = Rectangle.init(0, 0, 100, 200);
    const c = r.center();
    try std.testing.expectEqual(@as(i32, 50), c.x);
    try std.testing.expectEqual(@as(i32, 100), c.y);

    // Odd dimensions
    const r2 = Rectangle.init(0, 0, 101, 201);
    const c2 = r2.center();
    try std.testing.expectEqual(@as(i32, 50), c2.x); // 101/2 = 50 (integer division)
    try std.testing.expectEqual(@as(i32, 100), c2.y);

    // With offset
    const r3 = Rectangle.init(10, 20, 100, 200);
    const c3 = r3.center();
    try std.testing.expectEqual(@as(i32, 60), c3.x);
    try std.testing.expectEqual(@as(i32, 120), c3.y);
}

test "Rectangle: centerLocation floating point" {
    const r = Rectangle.init(0, 0, 101, 201);
    const c = r.centerLocation();
    try std.testing.expectApproxEqAbs(@as(f64, 50.5), c.x, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 100.5), c.y, 0.0001);
}

test "Rectangle: empty and area" {
    const empty1 = Rectangle.init(10, 20, 0, 100);
    const empty2 = Rectangle.init(10, 20, 100, 0);
    const empty3 = Rectangle.EMPTY;
    const normal = Rectangle.init(10, 20, 100, 200);

    try std.testing.expect(empty1.isEmpty());
    try std.testing.expect(empty2.isEmpty());
    try std.testing.expect(empty3.isEmpty());
    try std.testing.expect(!normal.isEmpty());

    try std.testing.expectEqual(@as(u64, 0), empty1.area());
    try std.testing.expectEqual(@as(u64, 20000), normal.area());
}

test "Rectangle: contains point" {
    const r = Rectangle.init(10, 20, 100, 200);

    // Inside
    try std.testing.expect(r.contains(Point.init(50, 100)));
    try std.testing.expect(r.contains(Point.init(10, 20))); // Top-left corner (inclusive)

    // On boundary (right/bottom exclusive)
    try std.testing.expect(!r.contains(Point.init(110, 100))); // Right edge
    try std.testing.expect(!r.contains(Point.init(50, 220))); // Bottom edge

    // Outside
    try std.testing.expect(!r.contains(Point.init(5, 100)));
    try std.testing.expect(!r.contains(Point.init(50, 15)));
    try std.testing.expect(!r.contains(Point.init(150, 100)));
    try std.testing.expect(!r.contains(Point.init(50, 250)));
}

test "Rectangle: contains rect" {
    const outer = Rectangle.init(0, 0, 100, 100);
    const inner = Rectangle.init(10, 10, 50, 50);
    const overlapping = Rectangle.init(50, 50, 100, 100);
    const outside = Rectangle.init(200, 200, 50, 50);

    try std.testing.expect(outer.containsRect(inner));
    try std.testing.expect(!outer.containsRect(overlapping));
    try std.testing.expect(!outer.containsRect(outside));

    // Empty rect is contained by anything
    try std.testing.expect(outer.containsRect(Rectangle.EMPTY));

    // Rect contains itself
    try std.testing.expect(outer.containsRect(outer));
}

test "Rectangle: intersection detection" {
    const r1 = Rectangle.init(0, 0, 100, 100);
    const r2 = Rectangle.init(50, 50, 100, 100); // Overlapping
    const r3 = Rectangle.init(100, 0, 100, 100); // Adjacent (not overlapping)
    const r4 = Rectangle.init(200, 200, 50, 50); // Separate

    try std.testing.expect(r1.intersects(r2));
    try std.testing.expect(!r1.intersects(r3)); // Adjacent doesn't count
    try std.testing.expect(!r1.intersects(r4));

    // Empty rectangles don't intersect
    try std.testing.expect(!r1.intersects(Rectangle.EMPTY));
    try std.testing.expect(!Rectangle.EMPTY.intersects(r1));
}

test "Rectangle: intersection calculation" {
    const r1 = Rectangle.init(0, 0, 100, 100);
    const r2 = Rectangle.init(50, 50, 100, 100);

    const inter = r1.intersection(r2);
    try std.testing.expectEqual(@as(i32, 50), inter.x);
    try std.testing.expectEqual(@as(i32, 50), inter.y);
    try std.testing.expectEqual(@as(u32, 50), inter.width);
    try std.testing.expectEqual(@as(u32, 50), inter.height);

    // No intersection returns empty
    const r3 = Rectangle.init(200, 200, 50, 50);
    const no_inter = r1.intersection(r3);
    try std.testing.expect(no_inter.isEmpty());
}

test "Rectangle: bounding rect (union)" {
    const r1 = Rectangle.init(0, 0, 50, 50);
    const r2 = Rectangle.init(100, 100, 50, 50);

    const bounds = r1.boundingRect(r2);
    try std.testing.expectEqual(@as(i32, 0), bounds.x);
    try std.testing.expectEqual(@as(i32, 0), bounds.y);
    try std.testing.expectEqual(@as(u32, 150), bounds.width);
    try std.testing.expectEqual(@as(u32, 150), bounds.height);

    // Union with empty returns other
    const with_empty = r1.boundingRect(Rectangle.EMPTY);
    try std.testing.expect(r1.eql(with_empty));
}

test "Rectangle: expand and shrink" {
    const r = Rectangle.init(50, 50, 100, 100);

    // Expand
    const expanded = r.expand(10);
    try std.testing.expectEqual(@as(i32, 40), expanded.x);
    try std.testing.expectEqual(@as(i32, 40), expanded.y);
    try std.testing.expectEqual(@as(u32, 120), expanded.width);
    try std.testing.expectEqual(@as(u32, 120), expanded.height);

    // Shrink
    const shrunk = r.shrink(10);
    try std.testing.expectEqual(@as(i32, 60), shrunk.x);
    try std.testing.expectEqual(@as(i32, 60), shrunk.y);
    try std.testing.expectEqual(@as(u32, 80), shrunk.width);
    try std.testing.expectEqual(@as(u32, 80), shrunk.height);

    // Shrink too much returns empty
    const over_shrunk = r.shrink(60);
    try std.testing.expect(over_shrunk.isEmpty());
}

test "Rectangle: negative coordinates" {
    const r = Rectangle.init(-50, -50, 100, 100);

    try std.testing.expect(r.contains(Point.init(0, 0)));
    try std.testing.expect(r.contains(Point.init(-50, -50)));
    try std.testing.expect(!r.contains(Point.init(-51, 0)));

    const c = r.center();
    try std.testing.expectEqual(@as(i32, 0), c.x);
    try std.testing.expectEqual(@as(i32, 0), c.y);
}

test "Rectangle: large coordinates (near i32 bounds)" {
    const large_x = std.math.maxInt(i32) - 100;
    const r = Rectangle.init(large_x, 0, 50, 50);

    // Should not overflow
    const c = r.center();
    try std.testing.expect(c.x > large_x);

    // Offset with saturation
    const offset_r = r.offset(1000, 0);
    try std.testing.expect(offset_r.x >= large_x); // Should saturate, not overflow
}

test "Rectangle: 1x1 pixel rectangle" {
    const r = Rectangle.init(100, 100, 1, 1);

    try std.testing.expect(!r.isEmpty());
    try std.testing.expectEqual(@as(u64, 1), r.area());
    try std.testing.expect(r.contains(Point.init(100, 100)));
    try std.testing.expect(!r.contains(Point.init(101, 100)));
}
