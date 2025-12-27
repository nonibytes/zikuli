//! Zikuli CLI - Command-line interface for Zikuli visual automation
//!
//! This executable provides command-line access to Zikuli functionality.
//! For library usage, import the 'zikuli' module directly.

const std = @import("std");
const zikuli = @import("zikuli");

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print(
        \\
        \\  _____  _  _            _  _
        \\ |__  / (_)| | __ _   _ | |(_)
        \\   / /  | || |/ /| | | || || |
        \\  / /_  | ||   < | |_| || || |
        \\ /____| |_||_|\_\ \__,_||_||_|
        \\
        \\ Visual GUI Automation for Zig
        \\ Version: {s}
        \\
        \\ A faithful re-implementation of SikuliX.
        \\
        \\ Usage:
        \\   zikuli <command> [options]
        \\
        \\ Commands:
        \\   capture     Capture a screenshot
        \\   find        Find an image pattern on screen
        \\   click       Click on a pattern
        \\   type        Type text
        \\   version     Show version information
        \\
        \\ For more information, see: https://github.com/nonibytes/zikuli
        \\
        \\
    , .{zikuli.getVersion()});
}

test "main module loads" {
    // Just verify the module can be imported
    try std.testing.expectEqualStrings("0.1.0", zikuli.getVersion());
}
