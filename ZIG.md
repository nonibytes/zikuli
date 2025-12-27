# Zig 0.15 Syntax and API Notes

Reference for Zikuli development with Zig 0.15.2.

## Standard I/O

```zig
// Zig 0.15+ API (NOT std.io.getStdOut())
const stdout = std.fs.File.stdout().deprecatedWriter();
const stderr = std.fs.File.stderr().deprecatedWriter();
const stdin = std.fs.File.stdin().deprecatedReader();

// New buffered API (requires buffer)
var buffer: [4096]u8 = undefined;
const writer = std.fs.File.stdout().writer(&buffer);
const reader = std.fs.File.stdin().reader(&buffer);
```

## Print Formatting

```zig
try stdout.print("Value: {d}\n", .{42});
try stdout.print("String: {s}\n", .{"hello"});
try stdout.print("Hex: {x:0<16}\n", .{value});
try stdout.print("Float: {d:.2}\n", .{3.14159});
```

## Testing

```zig
const std = @import("std");

test "example test" {
    try std.testing.expectEqual(@as(u32, 42), someFunction());
    try std.testing.expectEqualStrings("expected", actual);
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), value, 0.001);
}
```

## SemanticVersion

```zig
pub const version = std.SemanticVersion{
    .major = 0,
    .minor = 1,
    .patch = 0,
};
```

## Error Handling

```zig
// Error union
fn doSomething() !u32 {
    return error.SomeError;
}

// Error set
const MyErrors = error{
    OutOfBounds,
    InvalidInput,
};

// Catch and handle
const result = doSomething() catch |err| {
    std.debug.print("Error: {}\n", .{err});
    return err;
};

// Try (propagate error)
const result = try doSomething();
```

## Memory Allocation

```zig
// Get allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
defer _ = gpa.deinit();
const allocator = gpa.allocator();

// Allocate slice
const buffer = try allocator.alloc(u8, 1024);
defer allocator.free(buffer);

// Create single item
const ptr = try allocator.create(MyStruct);
defer allocator.destroy(ptr);
```

## C Interop

```zig
const c = @cImport({
    @cInclude("xcb/xcb.h");
    @cInclude("xcb/xcb_image.h");
    @cInclude("opencv2/core.h");
});

// Call C function
const result = c.xcb_connect(null, null);

// Cast integers
const x: i32 = @intCast(value);
const y: u32 = @intCast(self.width);

// Pointer casts
const ptr: [*]u8 = @ptrCast(c_ptr);
```

## Struct Methods

```zig
pub const Point = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Point {
        return .{ .x = x, .y = y };
    }

    pub fn offset(self: Point, dx: i32, dy: i32) Point {
        return .{ .x = self.x + dx, .y = self.y + dy };
    }

    pub fn deinit(self: *Point) void {
        // cleanup
    }
};
```

## Optional Types

```zig
fn find(target: Image) ?Match {
    if (found) {
        return Match{ ... };
    }
    return null;
}

// Usage
if (region.find(pattern)) |match| {
    try match.click();
} else {
    std.debug.print("Not found\n", .{});
}
```

## Slices and Arrays

```zig
// Fixed array
var buffer: [1024]u8 = undefined;

// Slice from array
const slice: []u8 = buffer[0..100];

// Sentinel-terminated string
const str: [:0]const u8 = "hello";
```

## Build System (build.zig)

```zig
// Add module
const mod = b.addModule("zikuli", .{
    .root_source_file = b.path("src/root.zig"),
    .target = target,
});

// Add executable with module import
const exe = b.addExecutable(.{
    .name = "zikuli",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zikuli", .module = mod },
        },
    }),
});

// Link system library
exe.linkSystemLibrary("xcb");
exe.linkSystemLibrary("opencv4");
```

## Multi-line Strings

```zig
const banner =
    \\  _____  _  _            _  _
    \\ |__  / (_)| | __ _   _ | |(_)
    \\   / /  | || |/ /| | | || || |
    \\  / /_  | ||   < | |_| || || |
    \\ /____| |_||_|\_\ \__,_||_||_|
;
```

## Defer and Errdefer

```zig
pub fn openAndProcess(path: []const u8) !void {
    const file = try std.fs.openFileAbsolute(path, .{});
    defer file.close();  // Always runs

    const buffer = try allocator.alloc(u8, 1024);
    errdefer allocator.free(buffer);  // Only on error

    // ... processing
}
```

## Comptime

```zig
// Compile-time known values
const SIZE = comptime blk: {
    const base = 1024;
    break :blk base * base;
};

// Generic function
fn max(comptime T: type, a: T, b: T) T {
    return if (a > b) a else b;
}
```

## Zig 0.15 Breaking Changes from 0.13

1. `std.io.getStdOut()` → `std.fs.File.stdout()`
2. Writer/Reader now require buffer parameter (use `deprecatedWriter()` for old behavior)
3. Build API changes in `std.Build`
4. Package format changes in `build.zig.zon` (.name uses .identifier syntax)
