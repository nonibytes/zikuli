//! Error types for Zikuli
//!
//! Implements SikuliX-style exception handling:
//! - FindFailed: thrown when an image/pattern is not found
//! - Timeout: thrown when an operation times out
//!
//! Based on SikuliX FindFailed.java analysis

const std = @import("std");

/// Find failed - equivalent to SikuliX FindFailed exception
/// Thrown when find(), click(target), type(target) operations fail to locate the target
pub const FindFailed = struct {
    /// The target that was not found (pattern description or filename)
    target: []const u8,
    /// The region that was searched
    region_str: []const u8,
    /// Time spent searching (milliseconds)
    elapsed_ms: i64,
    /// Allocator used for strings (for cleanup)
    allocator: ?std.mem.Allocator,

    pub fn init(target: []const u8, region_str: []const u8, elapsed_ms: i64) FindFailed {
        return .{
            .target = target,
            .region_str = region_str,
            .elapsed_ms = elapsed_ms,
            .allocator = null,
        };
    }

    pub fn initAlloc(allocator: std.mem.Allocator, target: []const u8, region_str: []const u8, elapsed_ms: i64) !FindFailed {
        const target_copy = try allocator.dupe(u8, target);
        errdefer allocator.free(target_copy);
        const region_copy = try allocator.dupe(u8, region_str);

        return .{
            .target = target_copy,
            .region_str = region_copy,
            .elapsed_ms = elapsed_ms,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FindFailed) void {
        if (self.allocator) |alloc| {
            alloc.free(self.target);
            alloc.free(self.region_str);
        }
    }

    pub fn format(
        self: FindFailed,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("FindFailed: '{s}' not found in {s} after {d}ms", .{
            self.target,
            self.region_str,
            self.elapsed_ms,
        });
    }
};

/// Find failed response - how to handle FindFailed errors
/// Matches SikuliX FindFailedResponse enum
pub const FindFailedResponse = enum {
    /// Abort immediately (throw/return error)
    abort,
    /// Skip and continue (return null)
    skip,
    /// Prompt user for action (not implemented in CLI)
    prompt,
    /// Retry the find operation
    retry,
    /// Call custom handler
    handle,
};

/// Global find failed response setting
var global_find_failed_response: FindFailedResponse = .abort;

/// Set global find failed response
pub fn setFindFailedResponse(response: FindFailedResponse) void {
    global_find_failed_response = response;
}

/// Get global find failed response
pub fn getFindFailedResponse() FindFailedResponse {
    return global_find_failed_response;
}

/// Timeout error - when operations exceed their time limit
pub const TimeoutError = struct {
    operation: []const u8,
    timeout_ms: i64,

    pub fn init(operation: []const u8, timeout_ms: i64) TimeoutError {
        return .{
            .operation = operation,
            .timeout_ms = timeout_ms,
        };
    }

    pub fn format(
        self: TimeoutError,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;
        try writer.print("Timeout: '{s}' exceeded {d}ms", .{ self.operation, self.timeout_ms });
    }
};

/// Zikuli error set - all error types that can be returned
pub const ZikuliError = error{
    /// Find operation failed to locate target
    FindFailed,
    /// Operation timed out
    Timeout,
    /// Pattern/target not found (legacy - use FindFailed)
    PatternNotFound,
    /// Invalid region or coordinates
    InvalidRegion,
    /// Screen capture failed
    CaptureError,
    /// Display connection failed
    DisplayError,
    /// Invalid argument
    InvalidArgument,
    /// Operation not supported
    NotSupported,
    /// Out of memory
    OutOfMemory,
};

// ============================================================================
// TESTS
// ============================================================================

test "FindFailed: basic creation" {
    const ff = FindFailed.init("button.png", "Region[0,0 1920x1080]", 3000);
    try std.testing.expectEqualStrings("button.png", ff.target);
    try std.testing.expectEqual(@as(i64, 3000), ff.elapsed_ms);
}

test "FindFailedResponse: default is abort" {
    try std.testing.expectEqual(FindFailedResponse.abort, getFindFailedResponse());
}

test "FindFailedResponse: can be changed" {
    const original = getFindFailedResponse();
    defer setFindFailedResponse(original);

    setFindFailedResponse(.skip);
    try std.testing.expectEqual(FindFailedResponse.skip, getFindFailedResponse());
}

test "TimeoutError: basic creation" {
    const te = TimeoutError.init("wait", 5000);
    try std.testing.expectEqualStrings("wait", te.operation);
    try std.testing.expectEqual(@as(i64, 5000), te.timeout_ms);
}
