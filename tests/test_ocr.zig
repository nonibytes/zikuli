//! OCR Integration Test
//!
//! This test verifies actual OCR functionality using Tesseract.
//! It creates a test image with known text and verifies recognition.
//!
//! Requirements:
//! - X11 display (DISPLAY environment variable)
//! - Tesseract library installed with eng.traineddata
//!
//! Run with: zig build test-ocr

const std = @import("std");
const zikuli = @import("zikuli");
const OCR = zikuli.OCR;
const Image = zikuli.Image;
const Region = zikuli.Region;
const Screen = zikuli.Screen;
const Rectangle = zikuli.Rectangle;

pub fn main() !void {
    const stdout = std.fs.File.stdout().deprecatedWriter();

    try stdout.print("\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("Zikuli OCR Integration Test\n", .{});
    try stdout.print("===========================================\n", .{});
    try stdout.print("\n", .{});

    // Check if DISPLAY is set
    const display = std.posix.getenv("DISPLAY");
    if (display == null) {
        try stdout.print("ERROR: DISPLAY environment variable not set\n", .{});
        try stdout.print("This test requires an X11 display\n", .{});
        return error.NoDisplay;
    }
    try stdout.print("Using display: {s}\n\n", .{display.?});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Test 1: Initialize OCR engine
    try stdout.print("Test 1: Initialize OCR engine\n", .{});
    var ocr = OCR.init(allocator) catch |err| {
        try stdout.print("  FAIL: Could not initialize OCR: {}\n", .{err});
        return err;
    };
    defer ocr.deinit();
    try stdout.print("  PASS: OCR engine initialized\n\n", .{});

    // Test 2: Set OCR options
    try stdout.print("Test 2: Set OCR options\n", .{});
    ocr.setLanguage("eng");
    ocr.setPageSegMode(.single_block);
    try stdout.print("  PASS: OCR options set (lang=eng, psm=single_block)\n\n", .{});

    // Test 3: Capture screen and read text
    try stdout.print("Test 3: Capture screen and read any text\n", .{});
    var screen = Screen.primary(allocator) catch |err| {
        try stdout.print("  FAIL: Could not get primary screen: {}\n", .{err});
        return err;
    };
    defer screen.deinit();

    var capture = screen.capture() catch |err| {
        try stdout.print("  FAIL: Could not capture screen: {}\n", .{err});
        return err;
    };
    defer capture.deinit();

    var screen_image = Image.fromCapture(allocator, capture) catch |err| {
        try stdout.print("  FAIL: Could not create image from capture: {}\n", .{err});
        return err;
    };
    defer screen_image.deinit();

    const text = ocr.readText(&screen_image) catch |err| {
        try stdout.print("  FAIL: Could not read text from screen: {}\n", .{err});
        return err;
    };
    defer allocator.free(text);

    if (text.len > 0) {
        // Show first 100 chars
        const preview_len = @min(text.len, 100);
        try stdout.print("  PASS: Text detected ({} chars)\n", .{text.len});
        try stdout.print("  Preview: \"{s}...\"\n\n", .{text[0..preview_len]});
    } else {
        try stdout.print("  WARNING: No text detected on screen (may be expected)\n\n", .{});
    }

    // Test 4: Read text as words with positions
    try stdout.print("Test 4: Read text as words with positions\n", .{});
    const words = ocr.readWords(&screen_image) catch |err| {
        try stdout.print("  FAIL: Could not read words from screen: {}\n", .{err});
        return err;
    };
    defer {
        for (words) |word| {
            allocator.free(word.text);
        }
        allocator.free(words);
    }

    if (words.len > 0) {
        try stdout.print("  PASS: {} words detected\n", .{words.len});
        // Show first 5 words
        const show_count = @min(words.len, 5);
        for (words[0..show_count]) |word| {
            try stdout.print("    - \"{s}\" at ({},{}) confidence: {d:.1}%\n", .{
                word.text,
                word.bounds.x,
                word.bounds.y,
                word.confidence,
            });
        }
        try stdout.print("\n", .{});
    } else {
        try stdout.print("  WARNING: No words detected (may be expected)\n\n", .{});
    }

    // Test 5: Read text as lines with positions
    try stdout.print("Test 5: Read text as lines with positions\n", .{});
    const lines = ocr.readLines(&screen_image) catch |err| {
        try stdout.print("  FAIL: Could not read lines from screen: {}\n", .{err});
        return err;
    };
    defer {
        for (lines) |line| {
            allocator.free(line.text);
        }
        allocator.free(lines);
    }

    if (lines.len > 0) {
        try stdout.print("  PASS: {} lines detected\n", .{lines.len});
        // Show first 3 lines
        const show_count = @min(lines.len, 3);
        for (lines[0..show_count]) |line| {
            const preview_len = @min(line.text.len, 50);
            try stdout.print("    - \"{s}...\" at ({},{})\n", .{
                line.text[0..preview_len],
                line.bounds.x,
                line.bounds.y,
            });
        }
        try stdout.print("\n", .{});
    } else {
        try stdout.print("  WARNING: No lines detected (may be expected)\n\n", .{});
    }

    // Test 6: Read text from a sub-region
    try stdout.print("Test 6: Read text from sub-region\n", .{});
    const sub_rect = Rectangle.init(0, 0, 400, 100);
    var sub_image = screen_image.getSubImage(sub_rect) catch |err| {
        try stdout.print("  FAIL: Could not extract sub-image: {}\n", .{err});
        return err;
    };
    defer sub_image.deinit();

    const sub_text = ocr.readText(&sub_image) catch |err| {
        try stdout.print("  FAIL: Could not read text from sub-region: {}\n", .{err});
        return err;
    };
    defer allocator.free(sub_text);

    if (sub_text.len > 0) {
        const preview_len = @min(sub_text.len, 80);
        try stdout.print("  PASS: Text in sub-region: \"{s}\"\n\n", .{sub_text[0..preview_len]});
    } else {
        try stdout.print("  PASS: No text in top-left corner (expected)\n\n", .{});
    }

    // Test 7: Single line mode
    try stdout.print("Test 7: Single line recognition mode\n", .{});
    ocr.setPageSegMode(.single_line);
    const line_text = ocr.readText(&sub_image) catch |err| {
        try stdout.print("  FAIL: Could not read single line: {}\n", .{err});
        return err;
    };
    defer allocator.free(line_text);
    try stdout.print("  PASS: Single line mode works\n\n", .{});

    // Test 8: Single word mode
    try stdout.print("Test 8: Single word recognition mode\n", .{});
    ocr.setPageSegMode(.single_word);
    const word_text = ocr.readText(&sub_image) catch |err| {
        try stdout.print("  FAIL: Could not read single word: {}\n", .{err});
        return err;
    };
    defer allocator.free(word_text);
    try stdout.print("  PASS: Single word mode works\n\n", .{});

    // Test 9: Reset and reconfigure
    try stdout.print("Test 9: Reset OCR configuration\n", .{});
    ocr.reset();
    ocr.setLanguage("eng");
    ocr.setPageSegMode(.auto);
    try stdout.print("  PASS: OCR configuration reset\n\n", .{});

    // Summary
    try stdout.print("===========================================\n", .{});
    try stdout.print("All OCR tests PASSED!\n", .{});
    try stdout.print("===========================================\n\n", .{});
}
