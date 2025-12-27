//! OCR Text Recognition Example
//!
//! This example demonstrates Zikuli's OCR functionality:
//! - Initializing the OCR engine
//! - Reading text from screen
//! - Getting words with positions
//! - Getting lines with positions
//!
//! Run with: zig build run-example-ocr
//!
//! Requirements:
//! - Tesseract OCR library installed
//! - eng.traineddata available

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Region = zikuli.Region;
const Image = zikuli.Image;
const OCR = zikuli.OCR;
const Rectangle = zikuli.Rectangle;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli OCR Text Recognition Example\n", .{});
    try stdout.print("Tesseract version: {s}\n", .{OCR.version()});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Step 1: Initialize OCR engine
    try stdout.print("Step 1: Initializing OCR engine...\n", .{});
    var ocr = try OCR.init(allocator);
    defer ocr.deinit();
    try stdout.print("  OCR engine ready\n", .{});

    // Configure OCR
    ocr.setLanguage("eng");
    ocr.setPageSegMode(.auto);
    try stdout.print("  Language: English, Mode: Auto\n", .{});

    // Step 2: Capture screen
    try stdout.print("\nStep 2: Capturing screen...\n", .{});
    var screen = try Screen.primary(allocator);
    defer screen.deinit();

    var capture = try screen.capture();
    defer capture.deinit();

    var full_image = try Image.fromCapture(allocator, capture);
    defer full_image.deinit();
    try stdout.print("  Captured {}x{} pixels\n", .{ full_image.width, full_image.height });

    // Step 3: Read all text from screen
    try stdout.print("\nStep 3: Reading text from screen...\n", .{});
    const all_text = try ocr.readText(&full_image);
    defer allocator.free(all_text);

    if (all_text.len > 0) {
        const preview_len = @min(all_text.len, 200);
        try stdout.print("  Found {} characters of text\n", .{all_text.len});
        try stdout.print("  Preview: \"{s}...\"\n", .{all_text[0..preview_len]});
    } else {
        try stdout.print("  No text found on screen\n", .{});
    }

    // Step 4: Read words with positions
    try stdout.print("\nStep 4: Reading words with positions...\n", .{});
    const words = try ocr.readWords(&full_image);
    defer {
        for (words) |word| {
            allocator.free(word.text);
        }
        allocator.free(words);
    }

    try stdout.print("  Found {} words\n", .{words.len});
    if (words.len > 0) {
        const show_count = @min(words.len, 10);
        try stdout.print("  Top {} words:\n", .{show_count});
        for (words[0..show_count]) |word| {
            const word_preview = word.text[0..@min(word.text.len, 20)];
            try stdout.print("    \"{s}\" at ({},{}) conf: {d:.1}%\n", .{
                word_preview,
                word.bounds.x,
                word.bounds.y,
                word.confidence,
            });
        }
    }

    // Step 5: Read lines with positions
    try stdout.print("\nStep 5: Reading lines with positions...\n", .{});
    const lines = try ocr.readLines(&full_image);
    defer {
        for (lines) |line| {
            allocator.free(line.text);
        }
        allocator.free(lines);
    }

    try stdout.print("  Found {} lines\n", .{lines.len});
    if (lines.len > 0) {
        const show_count = @min(lines.len, 5);
        try stdout.print("  Top {} lines:\n", .{show_count});
        for (lines[0..show_count]) |line| {
            const line_preview = line.text[0..@min(line.text.len, 50)];
            try stdout.print("    \"{s}...\" at ({},{})\n", .{
                line_preview,
                line.bounds.x,
                line.bounds.y,
            });
        }
    }

    // Step 6: OCR on a specific region
    try stdout.print("\nStep 6: OCR on specific region (top-left 600x200)...\n", .{});
    const region_rect = Rectangle.init(0, 0, 600, 200);
    var region_image = try full_image.getSubImage(region_rect);
    defer region_image.deinit();

    ocr.setPageSegMode(.single_block);
    const region_text = try ocr.readText(&region_image);
    defer allocator.free(region_text);

    if (region_text.len > 0) {
        const preview_len = @min(region_text.len, 150);
        try stdout.print("  Text in region: \"{s}\"\n", .{region_text[0..preview_len]});
    } else {
        try stdout.print("  No text in this region\n", .{});
    }

    // Summary
    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("OCR example completed!\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});
}
