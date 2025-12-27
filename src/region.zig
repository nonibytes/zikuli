//! Region type for Zikuli
//!
//! A Region represents a rectangular area that can be used for
//! find operations, mouse actions, and screen capture.
//!
//! Phase 1: Basic geometry only (no screen operations yet)
//! Later phases will add: find(), click(), type(), wait(), etc.
//!
//! Based on SikuliX Region.java analysis:
//! - Region has x, y, w, h (width/height)
//! - Region operations return Match or list of Match
//! - Region can be offset, resized, and split
//! - Default autoWaitTimeout is 3.0 seconds
//! - Default similarity is 0.7

const std = @import("std");
const geometry = @import("geometry.zig");
const Point = geometry.Point;
const Location = geometry.Location;
const Rectangle = geometry.Rectangle;

// Phase 7: Integration imports
const screen_mod = @import("screen.zig");
const image_mod = @import("image.zig");
const finder_mod = @import("finder.zig");
const match_mod = @import("match.zig");
const xtest = @import("xtest.zig");
const keyboard_mod = @import("keyboard.zig");
const errors = @import("errors.zig");

const Screen = screen_mod.Screen;
const Image = image_mod.Image;
const Finder = finder_mod.Finder;
const Match = match_mod.Match;
const Mouse = xtest.Mouse;
const Keyboard = keyboard_mod.Keyboard;
const KeySym = keyboard_mod.KeySym;
const Modifier = keyboard_mod.Modifier;
const FindFailed = errors.FindFailed;
const FindFailedResponse = errors.FindFailedResponse;

/// Default wait timeout for find operations (seconds)
pub const DEFAULT_AUTO_WAIT_TIMEOUT: f64 = 3.0;

/// Default highlight duration (seconds)
pub const DEFAULT_HIGHLIGHT_DURATION: f64 = 2.0;

/// A Region represents a rectangular screen area for automation operations
pub const Region = struct {
    /// The bounding rectangle
    rect: Rectangle,

    /// Timeout for find operations (seconds)
    auto_wait_timeout: f64,

    /// Screen index (for multi-monitor support)
    screen_id: i32,

    /// Create a region from a rectangle
    pub fn init(rect: Rectangle) Region {
        return .{
            .rect = rect,
            .auto_wait_timeout = DEFAULT_AUTO_WAIT_TIMEOUT,
            .screen_id = 0,
        };
    }

    /// Create a region from position and size
    pub fn initAt(pos_x: i32, pos_y: i32, w: u32, h: u32) Region {
        return init(Rectangle.init(pos_x, pos_y, w, h));
    }

    /// Create a region from two corner points
    pub fn fromPoints(p1: Point, p2: Point) Region {
        return init(Rectangle.fromPoints(p1, p2));
    }

    // ========================================================================
    // Position and Size Accessors
    // ========================================================================

    pub fn x(self: Region) i32 {
        return self.rect.x;
    }

    pub fn y(self: Region) i32 {
        return self.rect.y;
    }

    pub fn width(self: Region) u32 {
        return self.rect.width;
    }

    pub fn height(self: Region) u32 {
        return self.rect.height;
    }

    pub fn right(self: Region) i32 {
        return self.rect.right();
    }

    pub fn bottom(self: Region) i32 {
        return self.rect.bottom();
    }

    /// Set x position
    pub fn setX(self: *Region, new_x: i32) void {
        self.rect.x = new_x;
    }

    /// Set y position
    pub fn setY(self: *Region, new_y: i32) void {
        self.rect.y = new_y;
    }

    /// Set width (minimum 1)
    pub fn setWidth(self: *Region, new_width: u32) void {
        self.rect.width = @max(1, new_width);
    }

    /// Set height (minimum 1)
    pub fn setHeight(self: *Region, new_height: u32) void {
        self.rect.height = @max(1, new_height);
    }

    // ========================================================================
    // Geometry Operations
    // ========================================================================

    /// Get center point
    pub fn center(self: Region) Point {
        return self.rect.center();
    }

    /// Get center as location
    pub fn centerLocation(self: Region) Location {
        return self.rect.centerLocation();
    }

    /// Get top-left corner
    pub fn topLeft(self: Region) Point {
        return self.rect.topLeft();
    }

    /// Get top-right corner
    pub fn topRight(self: Region) Point {
        return self.rect.topRight();
    }

    /// Get bottom-left corner
    pub fn bottomLeft(self: Region) Point {
        return self.rect.bottomLeft();
    }

    /// Get bottom-right corner
    pub fn bottomRight(self: Region) Point {
        return self.rect.bottomRight();
    }

    /// Get area in pixels
    pub fn area(self: Region) u64 {
        return self.rect.area();
    }

    /// Check if point is inside region
    pub fn contains(self: Region, p: Point) bool {
        return self.rect.contains(p);
    }

    /// Check if another region is fully contained
    pub fn containsRegion(self: Region, other: Region) bool {
        return self.rect.containsRect(other.rect);
    }

    /// Check if regions intersect
    pub fn intersects(self: Region, other: Region) bool {
        return self.rect.intersects(other.rect);
    }

    // ========================================================================
    // Region Transformations (SikuliX-style)
    // ========================================================================

    /// Offset region position
    pub fn offset(self: Region, dx: i32, dy: i32) Region {
        var result = self;
        result.rect = self.rect.offset(dx, dy);
        return result;
    }

    /// Expand region by amount on all sides
    pub fn grow(self: Region, amount: i32) Region {
        var result = self;
        result.rect = self.rect.expand(amount);
        return result;
    }

    /// Expand region by different amounts
    pub fn growBy(self: Region, left_amt: i32, top_amt: i32, right_amt: i32, bottom_amt: i32) Region {
        const new_x = self.rect.x -| left_amt;
        const new_y = self.rect.y -| top_amt;
        const new_w = self.rect.width +| @as(u32, @intCast(@max(0, left_amt))) +| @as(u32, @intCast(@max(0, right_amt)));
        const new_h = self.rect.height +| @as(u32, @intCast(@max(0, top_amt))) +| @as(u32, @intCast(@max(0, bottom_amt)));

        var result = self;
        result.rect = Rectangle.init(new_x, new_y, new_w, new_h);
        return result;
    }

    /// Get the left portion of the region
    pub fn left(self: Region, amount: u32) Region {
        var result = self;
        result.rect.width = @min(amount, self.rect.width);
        return result;
    }

    /// Get the right portion of the region
    pub fn rightPortion(self: Region, amount: u32) Region {
        const capped = @min(amount, self.rect.width);
        var result = self;
        result.rect.x = self.rect.x +| @as(i32, @intCast(self.rect.width - capped));
        result.rect.width = capped;
        return result;
    }

    /// Get the top portion of the region
    pub fn top(self: Region, amount: u32) Region {
        var result = self;
        result.rect.height = @min(amount, self.rect.height);
        return result;
    }

    /// Get the bottom portion of the region
    pub fn bottomPortion(self: Region, amount: u32) Region {
        const capped = @min(amount, self.rect.height);
        var result = self;
        result.rect.y = self.rect.y +| @as(i32, @intCast(self.rect.height - capped));
        result.rect.height = capped;
        return result;
    }

    /// Get region above this one
    pub fn above(self: Region, distance: u32) Region {
        var result = self;
        result.rect.y = self.rect.y -| @as(i32, @intCast(distance));
        result.rect.height = distance;
        return result;
    }

    /// Get region below this one
    pub fn below(self: Region, distance: u32) Region {
        var result = self;
        result.rect.y = self.rect.bottom();
        result.rect.height = distance;
        return result;
    }

    /// Get region to the left of this one
    pub fn leftOf(self: Region, distance: u32) Region {
        var result = self;
        result.rect.x = self.rect.x -| @as(i32, @intCast(distance));
        result.rect.width = distance;
        return result;
    }

    /// Get region to the right of this one
    pub fn rightOf(self: Region, distance: u32) Region {
        var result = self;
        result.rect.x = self.rect.right();
        result.rect.width = distance;
        return result;
    }

    /// Get intersection with another region
    pub fn intersection(self: Region, other: Region) Region {
        var result = self;
        result.rect = self.rect.intersection(other.rect);
        return result;
    }

    /// Get bounding region of two regions (union)
    pub fn union_(self: Region, other: Region) Region {
        var result = self;
        result.rect = self.rect.boundingRect(other.rect);
        return result;
    }

    /// Set auto wait timeout
    pub fn withTimeout(self: Region, timeout: f64) Region {
        var result = self;
        result.auto_wait_timeout = timeout;
        return result;
    }

    /// Check if region is empty
    pub fn isEmpty(self: Region) bool {
        return self.rect.isEmpty();
    }

    /// Check equality
    pub fn eql(self: Region, other: Region) bool {
        return self.rect.eql(other.rect);
    }

    // ========================================================================
    // Phase 7: Integrated Operations (capture + find + input)
    // ========================================================================

    /// Capture this region as an Image
    pub fn captureImage(self: Region, allocator: std.mem.Allocator) !Image {
        var scr = try Screen.primary(allocator);
        defer scr.deinit();

        var captured = try scr.captureRegion(self.rect);
        defer captured.deinit();

        return Image.fromCapture(allocator, captured);
    }

    /// Find an image pattern within this region
    /// Returns null if not found
    pub fn findImage(self: Region, allocator: std.mem.Allocator, template: *const Image) !?Match {
        // Capture this region
        var region_image = try self.captureImage(allocator);
        defer region_image.deinit();

        // Search for template
        var finder = Finder.init(allocator, &region_image);
        defer finder.deinit();

        if (finder.find(template)) |match_result| {
            // Adjust match bounds to screen coordinates
            return Match.initAt(
                self.rect.x + match_result.bounds.x,
                self.rect.y + match_result.bounds.y,
                match_result.bounds.width,
                match_result.bounds.height,
                match_result.score,
            );
        }

        return null;
    }

    /// Check if an image exists in this region
    pub fn existsImage(self: Region, allocator: std.mem.Allocator, template: *const Image, timeout_sec: f64) !bool {
        const start = std.time.milliTimestamp();
        const timeout_ms: i64 = @intFromFloat(timeout_sec * 1000.0);

        while (true) {
            if (try self.findImage(allocator, template)) |_| {
                return true;
            }

            const elapsed = std.time.milliTimestamp() - start;
            if (elapsed >= timeout_ms) {
                return false;
            }

            // Small delay between retries
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    }

    /// Wait for an image to appear in this region
    /// Returns the Match if found, null if timeout
    pub fn waitImage(self: Region, allocator: std.mem.Allocator, template: *const Image, timeout_sec: f64) !?Match {
        const start = std.time.milliTimestamp();
        const timeout_ms: i64 = @intFromFloat(timeout_sec * 1000.0);

        while (true) {
            if (try self.findImage(allocator, template)) |match_result| {
                return match_result;
            }

            const elapsed = std.time.milliTimestamp() - start;
            if (elapsed >= timeout_ms) {
                return null;
            }

            // Small delay between retries
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    }

    /// Wait for an image to vanish from this region
    /// Returns true if vanished, false if still present after timeout
    pub fn waitVanishImage(self: Region, allocator: std.mem.Allocator, template: *const Image, timeout_sec: f64) !bool {
        const start = std.time.milliTimestamp();
        const timeout_ms: i64 = @intFromFloat(timeout_sec * 1000.0);

        while (true) {
            if (try self.findImage(allocator, template)) |_| {
                // Still there, check timeout
                const elapsed = std.time.milliTimestamp() - start;
                if (elapsed >= timeout_ms) {
                    return false; // Still present after timeout
                }
                std.Thread.sleep(100 * std.time.ns_per_ms);
            } else {
                return true; // Vanished
            }
        }
    }

    /// Find and click on an image pattern
    pub fn clickImage(self: Region, allocator: std.mem.Allocator, template: *const Image) !void {
        if (try self.findImage(allocator, template)) |match_result| {
            const target = match_result.center();
            try Mouse.clickAt(target.x, target.y, .left);
        } else {
            return error.PatternNotFound;
        }
    }

    /// Find and double-click on an image pattern
    pub fn doubleClickImage(self: Region, allocator: std.mem.Allocator, template: *const Image) !void {
        if (try self.findImage(allocator, template)) |match_result| {
            const target = match_result.center();
            try Mouse.smoothMoveTo(target.x, target.y);
            try Mouse.doubleClick(.left);
        } else {
            return error.PatternNotFound;
        }
    }

    /// Find and right-click on an image pattern
    pub fn rightClickImage(self: Region, allocator: std.mem.Allocator, template: *const Image) !void {
        if (try self.findImage(allocator, template)) |match_result| {
            const target = match_result.center();
            try Mouse.clickAt(target.x, target.y, .right);
        } else {
            return error.PatternNotFound;
        }
    }

    /// Click at the center of this region
    pub fn clickCenter(self: Region) !void {
        const c = self.center();
        try Mouse.clickAt(c.x, c.y, .left);
    }

    /// Double-click at the center of this region
    pub fn doubleClickCenter(self: Region) !void {
        const c = self.center();
        try Mouse.smoothMoveTo(c.x, c.y);
        try Mouse.doubleClick(.left);
    }

    /// Right-click at the center of this region
    pub fn rightClickCenter(self: Region) !void {
        const c = self.center();
        try Mouse.clickAt(c.x, c.y, .right);
    }

    // ========================================================================
    // SikuliX-Style API (Phase 11: Enhanced Operations)
    // ========================================================================

    /// Find an image pattern - throws FindFailed if not found (SikuliX-style)
    /// NOTE: Unlike wait(), find() does NOT wait/retry. It does a single immediate search.
    /// This matches SikuliX behavior: find() is "waiting 0 secs" (Region.java line 2280).
    /// Use wait() if you need to wait for the pattern to appear.
    /// Use exists() or findImage() if you want to check without throwing.
    pub fn find(self: Region, allocator: std.mem.Allocator, template: *const Image) !Match {
        if (try self.findImage(allocator, template)) |match_result| {
            return match_result;
        }
        return error.FindFailed;
    }

    /// Find all occurrences of an image pattern
    /// Returns a slice of all matches found. Caller must free with allocator.
    pub fn findAll(self: Region, allocator: std.mem.Allocator, template: *const Image) ![]Match {
        // Capture this region
        var region_image = try self.captureImage(allocator);
        defer region_image.deinit();

        // Search for all matches
        var finder = Finder.init(allocator, &region_image);
        defer finder.deinit();

        const local_matches = try finder.findAll(template);
        defer allocator.free(local_matches);

        // Convert to screen coordinates
        var result = try allocator.alloc(Match, local_matches.len);
        for (local_matches, 0..) |m, i| {
            result[i] = Match.initAt(
                self.rect.x + m.bounds.x,
                self.rect.y + m.bounds.y,
                m.bounds.width,
                m.bounds.height,
                m.score,
            );
        }

        return result;
    }

    /// Check if target exists (SikuliX-style)
    /// Returns the Match if found within timeout, null otherwise.
    /// Never throws FindFailed.
    pub fn exists(self: Region, allocator: std.mem.Allocator, template: *const Image, timeout_sec: ?f64) !?Match {
        const timeout = timeout_sec orelse self.auto_wait_timeout;
        return self.waitImage(allocator, template, timeout);
    }

    /// Wait for target to appear (SikuliX-style)
    /// Returns the Match if found, throws FindFailed if timeout.
    pub fn wait(self: Region, allocator: std.mem.Allocator, template: *const Image, timeout_sec: ?f64) !Match {
        const timeout = timeout_sec orelse self.auto_wait_timeout;
        if (try self.waitImage(allocator, template, timeout)) |match_result| {
            return match_result;
        }
        return error.FindFailed;
    }

    /// Wait for target to vanish (SikuliX-style)
    /// Returns true if vanished within timeout, false if still present.
    /// This matches SikuliX behavior: waitVanish() returns boolean, not exception.
    pub fn waitVanish(self: Region, allocator: std.mem.Allocator, template: *const Image, timeout_sec: ?f64) !bool {
        const timeout = timeout_sec orelse self.auto_wait_timeout;
        return self.waitVanishImage(allocator, template, timeout);
    }

    /// Click on target (SikuliX-style)
    /// Finds the target first, then clicks on it.
    /// Throws FindFailed if target not found.
    pub fn click(self: Region, allocator: std.mem.Allocator, template: *const Image) !Match {
        const match_result = try self.find(allocator, template);
        const target = match_result.center();
        try Mouse.clickAt(target.x, target.y, .left);
        return match_result;
    }

    /// Click with keyboard modifiers (Ctrl+Click, Shift+Click, etc.)
    /// Uses errdefer to ensure modifiers are released even if click fails.
    pub fn clickWithModifiers(self: Region, allocator: std.mem.Allocator, template: *const Image, modifiers: u32) !Match {
        const match_result = try self.find(allocator, template);
        const target = match_result.center();

        // Press modifiers with errdefer cleanup to prevent stuck keys
        var ctrl_pressed = false;
        var shift_pressed = false;
        var alt_pressed = false;
        var meta_pressed = false;

        errdefer {
            // Release any modifiers that were pressed if we error out
            if (meta_pressed) Keyboard.keyUp(KeySym.Meta_L) catch {};
            if (alt_pressed) Keyboard.keyUp(KeySym.Alt_L) catch {};
            if (shift_pressed) Keyboard.keyUp(KeySym.Shift_L) catch {};
            if (ctrl_pressed) Keyboard.keyUp(KeySym.Control_L) catch {};
        }

        if (modifiers & Modifier.CTRL != 0) {
            try Keyboard.keyDown(KeySym.Control_L);
            ctrl_pressed = true;
        }
        if (modifiers & Modifier.SHIFT != 0) {
            try Keyboard.keyDown(KeySym.Shift_L);
            shift_pressed = true;
        }
        if (modifiers & Modifier.ALT != 0) {
            try Keyboard.keyDown(KeySym.Alt_L);
            alt_pressed = true;
        }
        if (modifiers & Modifier.META != 0) {
            try Keyboard.keyDown(KeySym.Meta_L);
            meta_pressed = true;
        }

        // Click (if this fails, errdefer releases modifiers)
        try Mouse.clickAt(target.x, target.y, .left);

        // Release modifiers (success path)
        if (meta_pressed) try Keyboard.keyUp(KeySym.Meta_L);
        if (alt_pressed) try Keyboard.keyUp(KeySym.Alt_L);
        if (shift_pressed) try Keyboard.keyUp(KeySym.Shift_L);
        if (ctrl_pressed) try Keyboard.keyUp(KeySym.Control_L);

        return match_result;
    }

    /// Double-click on target (SikuliX-style)
    pub fn doubleClick(self: Region, allocator: std.mem.Allocator, template: *const Image) !Match {
        const match_result = try self.find(allocator, template);
        const target = match_result.center();
        try Mouse.smoothMoveTo(target.x, target.y);
        try Mouse.doubleClick(.left);
        return match_result;
    }

    /// Right-click on target (SikuliX-style)
    pub fn rightClick(self: Region, allocator: std.mem.Allocator, template: *const Image) !Match {
        const match_result = try self.find(allocator, template);
        const target = match_result.center();
        try Mouse.clickAt(target.x, target.y, .right);
        return match_result;
    }

    /// Hover over target (move mouse without clicking) (SikuliX-style)
    pub fn hover(self: Region, allocator: std.mem.Allocator, template: *const Image) !Match {
        const match_result = try self.find(allocator, template);
        const target = match_result.center();
        try Mouse.smoothMoveTo(target.x, target.y);
        return match_result;
    }

    /// Hover at region center
    pub fn hoverCenter(self: Region) !void {
        const c = self.center();
        try Mouse.smoothMoveTo(c.x, c.y);
    }

    /// Type text at target location (find, click, then type) (SikuliX-style)
    pub fn typeAt(self: Region, allocator: std.mem.Allocator, template: *const Image, text: []const u8) !Match {
        const match_result = try self.click(allocator, template);
        std.Thread.sleep(50 * std.time.ns_per_ms); // Small delay for focus
        try Keyboard.typeText(text);
        return match_result;
    }

    /// Type text at region center
    pub fn typeText(self: Region, text: []const u8) !void {
        try self.clickCenter();
        std.Thread.sleep(50 * std.time.ns_per_ms); // Small delay for focus
        try Keyboard.typeText(text);
    }

    /// Type text with modifiers (e.g., Ctrl+A to select all)
    /// Uses errdefer to ensure modifiers are released even if typing fails.
    pub fn typeWithModifiers(self: Region, text: []const u8, modifiers: u32) !void {
        try self.clickCenter();
        std.Thread.sleep(50 * std.time.ns_per_ms);

        // Press modifiers with errdefer cleanup to prevent stuck keys
        var ctrl_pressed = false;
        var shift_pressed = false;
        var alt_pressed = false;
        var meta_pressed = false;

        errdefer {
            // Release any modifiers that were pressed if we error out
            if (meta_pressed) Keyboard.keyUp(KeySym.Meta_L) catch {};
            if (alt_pressed) Keyboard.keyUp(KeySym.Alt_L) catch {};
            if (shift_pressed) Keyboard.keyUp(KeySym.Shift_L) catch {};
            if (ctrl_pressed) Keyboard.keyUp(KeySym.Control_L) catch {};
        }

        if (modifiers & Modifier.CTRL != 0) {
            try Keyboard.keyDown(KeySym.Control_L);
            ctrl_pressed = true;
        }
        if (modifiers & Modifier.SHIFT != 0) {
            try Keyboard.keyDown(KeySym.Shift_L);
            shift_pressed = true;
        }
        if (modifiers & Modifier.ALT != 0) {
            try Keyboard.keyDown(KeySym.Alt_L);
            alt_pressed = true;
        }
        if (modifiers & Modifier.META != 0) {
            try Keyboard.keyDown(KeySym.Meta_L);
            meta_pressed = true;
        }

        // Type text (if this fails, errdefer releases modifiers)
        try Keyboard.typeText(text);

        // Release modifiers (success path)
        if (meta_pressed) try Keyboard.keyUp(KeySym.Meta_L);
        if (alt_pressed) try Keyboard.keyUp(KeySym.Alt_L);
        if (shift_pressed) try Keyboard.keyUp(KeySym.Shift_L);
        if (ctrl_pressed) try Keyboard.keyUp(KeySym.Control_L);
    }

    /// Press a key or key combination (SikuliX-style hotkey)
    pub fn hotkey(self: Region, keysym: u32, modifiers: u32) !void {
        try self.clickCenter();
        std.Thread.sleep(50 * std.time.ns_per_ms);
        try Keyboard.pressWithModifiers(keysym, modifiers);
    }

    /// Drag from this region's center to a destination
    pub fn dragTo(self: Region, dest_x: i32, dest_y: i32) !void {
        const c = self.center();
        try Mouse.dragFromTo(c.x, c.y, dest_x, dest_y, .left);
    }

    /// Drag from target to a destination
    pub fn drag(self: Region, allocator: std.mem.Allocator, template: *const Image, dest_x: i32, dest_y: i32) !Match {
        const match_result = try self.find(allocator, template);
        const src = match_result.center();
        try Mouse.dragFromTo(src.x, src.y, dest_x, dest_y, .left);
        return match_result;
    }

    /// Drag from one target to another
    pub fn dragDrop(self: Region, allocator: std.mem.Allocator, src_template: *const Image, dest_template: *const Image) !void {
        const src_match = try self.find(allocator, src_template);
        const dest_match = try self.find(allocator, dest_template);
        const src = src_match.center();
        const dest = dest_match.center();
        try Mouse.dragFromTo(src.x, src.y, dest.x, dest.y, .left);
    }

    /// Drop at this region's center (used after drag)
    pub fn drop(self: Region) !void {
        const c = self.center();
        try Mouse.smoothMoveTo(c.x, c.y);
        try Mouse.buttonUp(.left);
    }

    /// Scroll wheel at region center
    pub fn wheel(self: Region, direction: xtest.MouseButton, steps: u32) !void {
        const c = self.center();
        try Mouse.smoothMoveTo(c.x, c.y);
        try Mouse.wheel(direction, steps);
    }

    /// Scroll up at region center
    pub fn wheelUp(self: Region, steps: u32) !void {
        try self.wheel(.wheel_up, steps);
    }

    /// Scroll down at region center
    pub fn wheelDown(self: Region, steps: u32) !void {
        try self.wheel(.wheel_down, steps);
    }

    /// Get a string representation for error messages
    pub fn toStr(self: Region) [64]u8 {
        var buf: [64]u8 = undefined;
        const written = std.fmt.bufPrint(&buf, "Region[{d},{d} {d}x{d}]", .{
            self.rect.x,
            self.rect.y,
            self.rect.width,
            self.rect.height,
        }) catch "Region[?]";
        var result: [64]u8 = undefined;
        @memcpy(result[0..written.len], written);
        result[written.len] = 0;
        return result;
    }

    pub fn format(
        self: Region,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Region[{d},{d} {d}x{d}]S({d})", .{
            self.rect.x,
            self.rect.y,
            self.rect.width,
            self.rect.height,
            self.screen_id,
        });
    }
};

// ============================================================================
// TESTS
// ============================================================================

test "Region: basic construction" {
    const r = Region.initAt(100, 200, 300, 400);
    try std.testing.expectEqual(@as(i32, 100), r.x());
    try std.testing.expectEqual(@as(i32, 200), r.y());
    try std.testing.expectEqual(@as(u32, 300), r.width());
    try std.testing.expectEqual(@as(u32, 400), r.height());
    try std.testing.expectApproxEqAbs(DEFAULT_AUTO_WAIT_TIMEOUT, r.auto_wait_timeout, 0.0001);
}

test "Region: from rectangle" {
    const rect = Rectangle.init(10, 20, 100, 50);
    const r = Region.init(rect);
    try std.testing.expect(r.rect.eql(rect));
}

test "Region: from points" {
    const r = Region.fromPoints(Point.init(0, 0), Point.init(100, 50));
    try std.testing.expectEqual(@as(i32, 0), r.x());
    try std.testing.expectEqual(@as(i32, 0), r.y());
    try std.testing.expectEqual(@as(u32, 100), r.width());
    try std.testing.expectEqual(@as(u32, 50), r.height());
}

test "Region: center" {
    const r = Region.initAt(100, 200, 50, 30);
    const c = r.center();
    try std.testing.expectEqual(@as(i32, 125), c.x);
    try std.testing.expectEqual(@as(i32, 215), c.y);
}

test "Region: corners" {
    const r = Region.initAt(100, 200, 50, 30);

    try std.testing.expect(r.topLeft().eql(Point.init(100, 200)));
    try std.testing.expect(r.topRight().eql(Point.init(150, 200)));
    try std.testing.expect(r.bottomLeft().eql(Point.init(100, 230)));
    try std.testing.expect(r.bottomRight().eql(Point.init(150, 230)));
}

test "Region: contains point" {
    const r = Region.initAt(100, 200, 50, 30);

    try std.testing.expect(r.contains(Point.init(110, 210)));
    try std.testing.expect(r.contains(Point.init(100, 200))); // Top-left (inclusive)
    try std.testing.expect(!r.contains(Point.init(150, 200))); // Right edge (exclusive)
    try std.testing.expect(!r.contains(Point.init(50, 210))); // Outside left
}

test "Region: offset" {
    const r = Region.initAt(100, 200, 50, 30);
    const moved = r.offset(10, -20);

    try std.testing.expectEqual(@as(i32, 110), moved.x());
    try std.testing.expectEqual(@as(i32, 180), moved.y());
    try std.testing.expectEqual(@as(u32, 50), moved.width()); // Size unchanged
}

test "Region: grow" {
    const r = Region.initAt(100, 200, 50, 30);
    const grown = r.grow(10);

    try std.testing.expectEqual(@as(i32, 90), grown.x());
    try std.testing.expectEqual(@as(i32, 190), grown.y());
    try std.testing.expectEqual(@as(u32, 70), grown.width());
    try std.testing.expectEqual(@as(u32, 50), grown.height());
}

test "Region: left portion" {
    const r = Region.initAt(100, 200, 100, 50);
    const left_portion = r.left(30);

    try std.testing.expectEqual(@as(i32, 100), left_portion.x());
    try std.testing.expectEqual(@as(u32, 30), left_portion.width());
}

test "Region: right portion" {
    const r = Region.initAt(100, 200, 100, 50);
    const right_portion = r.rightPortion(30);

    try std.testing.expectEqual(@as(i32, 170), right_portion.x());
    try std.testing.expectEqual(@as(u32, 30), right_portion.width());
}

test "Region: top portion" {
    const r = Region.initAt(100, 200, 100, 50);
    const top_portion = r.top(20);

    try std.testing.expectEqual(@as(i32, 200), top_portion.y());
    try std.testing.expectEqual(@as(u32, 20), top_portion.height());
}

test "Region: bottom portion" {
    const r = Region.initAt(100, 200, 100, 50);
    const bottom_portion = r.bottomPortion(20);

    try std.testing.expectEqual(@as(i32, 230), bottom_portion.y());
    try std.testing.expectEqual(@as(u32, 20), bottom_portion.height());
}

test "Region: above" {
    const r = Region.initAt(100, 200, 100, 50);
    const above_region = r.above(30);

    try std.testing.expectEqual(@as(i32, 170), above_region.y());
    try std.testing.expectEqual(@as(u32, 30), above_region.height());
    try std.testing.expectEqual(@as(u32, 100), above_region.width()); // Same width
}

test "Region: below" {
    const r = Region.initAt(100, 200, 100, 50);
    const below_region = r.below(30);

    try std.testing.expectEqual(@as(i32, 250), below_region.y());
    try std.testing.expectEqual(@as(u32, 30), below_region.height());
}

test "Region: leftOf" {
    const r = Region.initAt(100, 200, 100, 50);
    const left_of = r.leftOf(30);

    try std.testing.expectEqual(@as(i32, 70), left_of.x());
    try std.testing.expectEqual(@as(u32, 30), left_of.width());
    try std.testing.expectEqual(@as(u32, 50), left_of.height()); // Same height
}

test "Region: rightOf" {
    const r = Region.initAt(100, 200, 100, 50);
    const right_of = r.rightOf(30);

    try std.testing.expectEqual(@as(i32, 200), right_of.x());
    try std.testing.expectEqual(@as(u32, 30), right_of.width());
}

test "Region: intersection" {
    const r1 = Region.initAt(0, 0, 100, 100);
    const r2 = Region.initAt(50, 50, 100, 100);

    const inter = r1.intersection(r2);
    try std.testing.expectEqual(@as(i32, 50), inter.x());
    try std.testing.expectEqual(@as(i32, 50), inter.y());
    try std.testing.expectEqual(@as(u32, 50), inter.width());
    try std.testing.expectEqual(@as(u32, 50), inter.height());
}

test "Region: union" {
    const r1 = Region.initAt(0, 0, 50, 50);
    const r2 = Region.initAt(100, 100, 50, 50);

    const u = r1.union_(r2);
    try std.testing.expectEqual(@as(i32, 0), u.x());
    try std.testing.expectEqual(@as(i32, 0), u.y());
    try std.testing.expectEqual(@as(u32, 150), u.width());
    try std.testing.expectEqual(@as(u32, 150), u.height());
}

test "Region: withTimeout" {
    const r = Region.initAt(0, 0, 100, 100).withTimeout(5.0);
    try std.testing.expectApproxEqAbs(@as(f64, 5.0), r.auto_wait_timeout, 0.0001);
}

test "Region: setters" {
    var r = Region.initAt(100, 200, 50, 30);

    r.setX(150);
    try std.testing.expectEqual(@as(i32, 150), r.x());

    r.setY(250);
    try std.testing.expectEqual(@as(i32, 250), r.y());

    r.setWidth(80);
    try std.testing.expectEqual(@as(u32, 80), r.width());

    r.setHeight(60);
    try std.testing.expectEqual(@as(u32, 60), r.height());
}

test "Region: minimum width/height" {
    var r = Region.initAt(100, 200, 50, 30);

    // Setting to 0 should be capped to 1
    r.setWidth(0);
    try std.testing.expectEqual(@as(u32, 1), r.width());

    r.setHeight(0);
    try std.testing.expectEqual(@as(u32, 1), r.height());
}

test "Region: negative coordinates" {
    const r = Region.initAt(-100, -200, 300, 400);
    try std.testing.expectEqual(@as(i32, -100), r.x());
    try std.testing.expectEqual(@as(i32, -200), r.y());
    try std.testing.expect(r.contains(Point.init(0, 0)));
}

test "Region: containsRegion" {
    const outer = Region.initAt(0, 0, 100, 100);
    const inner = Region.initAt(10, 10, 50, 50);
    const overlapping = Region.initAt(50, 50, 100, 100);

    try std.testing.expect(outer.containsRegion(inner));
    try std.testing.expect(!outer.containsRegion(overlapping));
}

test "Region: intersects" {
    const r1 = Region.initAt(0, 0, 100, 100);
    const r2 = Region.initAt(50, 50, 100, 100);
    const r3 = Region.initAt(200, 200, 50, 50);

    try std.testing.expect(r1.intersects(r2));
    try std.testing.expect(!r1.intersects(r3));
}

test "Region: equality" {
    const r1 = Region.initAt(100, 200, 50, 30);
    const r2 = Region.initAt(100, 200, 50, 30);
    const r3 = Region.initAt(100, 200, 51, 30);

    try std.testing.expect(r1.eql(r2));
    try std.testing.expect(!r1.eql(r3));
}
