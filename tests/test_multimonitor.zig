//! Multi-Monitor Support Test
//!
//! Verifies that Zikuli correctly enumerates individual monitors
//! using XRandR, matching SikuliX behavior.
//!
//! Expected output on a dual-monitor setup:
//! - Screen(0) returns primary monitor (e.g., 1920x1080 at 0,0)
//! - Screen(1) returns second monitor (e.g., 1920x1080 at 1920,0)
//! - Virtual screen returns combined bounds (e.g., 3840x1080)

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Monitors = zikuli.Monitors;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║     Zikuli Multi-Monitor Support Test                    ║\n", .{});
    try stdout.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});

    // Test 1: Get monitor count
    try stdout.print("[TEST 1] Getting monitor count...\n", .{});
    const count = try Screen.getMonitorCount(allocator);
    try stdout.print("  Found {d} monitor(s)\n", .{count});

    if (count == 0) {
        try stdout.print("  ERROR: No monitors found!\n", .{});
        return;
    }
    try stdout.print("  ✅ PASS\n", .{});

    // Test 2: Enumerate all monitors
    try stdout.print("\n[TEST 2] Enumerating monitors...\n", .{});
    var monitors = try Monitors.init(allocator);
    defer monitors.deinit();

    const all_monitors = try monitors.getAll();
    defer monitors.freeMonitors(all_monitors);

    for (all_monitors) |mon| {
        try stdout.print("  Monitor {d}: {s}\n", .{ mon.id, mon.getName() });
        try stdout.print("    Bounds: x={d}, y={d}, {d}x{d}\n", .{
            mon.bounds.x,
            mon.bounds.y,
            mon.bounds.width,
            mon.bounds.height,
        });
        try stdout.print("    Primary: {}\n", .{mon.is_primary});
    }
    try stdout.print("  ✅ PASS\n", .{});

    // Test 3: Get primary screen (Screen 0)
    try stdout.print("\n[TEST 3] Getting primary screen (Screen 0)...\n", .{});
    var screen0 = try Screen.primary(allocator);
    defer screen0.deinit();

    try stdout.print("  Screen 0: {s}\n", .{screen0.getName()});
    try stdout.print("    Bounds: x={d}, y={d}, {d}x{d}\n", .{
        screen0.bounds.x,
        screen0.bounds.y,
        screen0.bounds.width,
        screen0.bounds.height,
    });

    // Verify it's not the combined virtual screen width
    if (count > 1 and screen0.bounds.width > 2560) {
        try stdout.print("  ⚠️  WARNING: Screen 0 width ({d}) seems too large for a single monitor!\n", .{screen0.bounds.width});
        try stdout.print("  ⚠️  This might be the combined virtual screen, not individual monitor.\n", .{});
    } else {
        try stdout.print("  ✅ PASS: Screen 0 returns individual monitor bounds\n", .{});
    }

    // Test 4: Get second screen if available
    if (count > 1) {
        try stdout.print("\n[TEST 4] Getting second screen (Screen 1)...\n", .{});
        var screen1 = try Screen.get(allocator, 1);
        defer screen1.deinit();

        try stdout.print("  Screen 1: {s}\n", .{screen1.getName()});
        try stdout.print("    Bounds: x={d}, y={d}, {d}x{d}\n", .{
            screen1.bounds.x,
            screen1.bounds.y,
            screen1.bounds.width,
            screen1.bounds.height,
        });

        // Verify screens have different positions
        if (screen0.bounds.x != screen1.bounds.x or screen0.bounds.y != screen1.bounds.y) {
            try stdout.print("  ✅ PASS: Screens have different positions\n", .{});
        } else {
            try stdout.print("  ⚠️  WARNING: Screens have same position - might be wrong\n", .{});
        }
    } else {
        try stdout.print("\n[TEST 4] Skipped: Only 1 monitor detected\n", .{});
    }

    // Test 5: Get virtual screen (combined)
    try stdout.print("\n[TEST 5] Getting virtual screen (combined)...\n", .{});
    var virtual = try Screen.virtual(allocator);
    defer virtual.deinit();

    try stdout.print("  Virtual Screen:\n", .{});
    try stdout.print("    Bounds: x={d}, y={d}, {d}x{d}\n", .{
        virtual.bounds.x,
        virtual.bounds.y,
        virtual.bounds.width,
        virtual.bounds.height,
    });

    // For multi-monitor, virtual should be larger than any single screen
    if (count > 1) {
        if (virtual.bounds.width > screen0.bounds.width or virtual.bounds.height > screen0.bounds.height) {
            try stdout.print("  ✅ PASS: Virtual screen is larger than primary monitor\n", .{});
        } else {
            try stdout.print("  ⚠️  WARNING: Virtual screen not larger than primary\n", .{});
        }
    }

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("╔══════════════════════════════════════════════════════════╗\n", .{});
    try stdout.print("║                    SUMMARY                               ║\n", .{});
    try stdout.print("╠══════════════════════════════════════════════════════════╣\n", .{});
    try stdout.print("║  Monitors detected: {d:<37} ║\n", .{count});
    try stdout.print("║  Primary (Screen 0): {d}x{d} at ({d},{d}){s}║\n", .{
        screen0.bounds.width,
        screen0.bounds.height,
        screen0.bounds.x,
        screen0.bounds.y,
        if (screen0.bounds.width <= 2560) "        " else "",
    });
    try stdout.print("║  Virtual screen: {d}x{d}{s}║\n", .{
        virtual.bounds.width,
        virtual.bounds.height,
        if (virtual.bounds.width <= 9999) "                       " else "",
    });
    try stdout.print("╚══════════════════════════════════════════════════════════╝\n", .{});
    try stdout.print("\n", .{});
}
