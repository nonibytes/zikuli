//! Screenshot Debug Test
//!
//! Captures a screenshot and saves it so we can see what OCR is actually seeing.

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Image = zikuli.Image;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n=== SCREENSHOT DEBUG ===\n\n", .{});

    // Capture primary monitor only
    try stdout.print("Capturing primary monitor (Screen 0)...\n", .{});
    var screen0 = try Screen.primary(allocator);
    defer screen0.deinit();

    try stdout.print("Screen 0 bounds: x={d}, y={d}, {d}x{d}\n", .{
        screen0.bounds.x,
        screen0.bounds.y,
        screen0.bounds.width,
        screen0.bounds.height,
    });

    var capture = try screen0.capture();
    defer capture.deinit();

    var img = try Image.fromCapture(allocator, capture);
    defer img.deinit();

    try stdout.print("Captured image: {d}x{d}\n", .{ img.width, img.height });

    // Save to file
    const filename = "/tmp/zikuli_screen0.png";
    try zikuli.image.savePng(&img, filename);
    try stdout.print("Saved to: {s}\n", .{filename});

    try stdout.print("\n=== END ===\n", .{});
}
