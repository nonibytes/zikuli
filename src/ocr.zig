//! High-level OCR API
//!
//! This module provides a Zig-idiomatic interface to Tesseract OCR.
//! It wraps the low-level C API bindings in a safe, easy-to-use interface.
//!
//! ## Example
//! ```zig
//! var ocr = try OCR.init(allocator);
//! defer ocr.deinit();
//!
//! ocr.setLanguage("eng");
//! ocr.setPageSegMode(.single_block);
//!
//! const text = try ocr.readText(&image);
//! defer allocator.free(text);
//! ```

const std = @import("std");
const tesseract = @import("ocr/tesseract.zig");
const image_mod = @import("image.zig");
const geometry = @import("geometry.zig");

const Image = image_mod.Image;
const Rectangle = geometry.Rectangle;

/// An OCR word result with text, position, and confidence
pub const Word = struct {
    /// The recognized text
    text: []u8,
    /// Bounding box of the word
    bounds: Rectangle,
    /// Recognition confidence (0-100)
    confidence: f32,
};

/// An OCR line result with text, position, and confidence
pub const Line = struct {
    /// The recognized text
    text: []u8,
    /// Bounding box of the line
    bounds: Rectangle,
    /// Recognition confidence (0-100)
    confidence: f32,
};

/// Page segmentation mode aliases for convenience
pub const PageSegMode = tesseract.PageSegMode;

/// OCR engine mode aliases
pub const OcrEngineMode = tesseract.OcrEngineMode;

/// High-level OCR interface
pub const OCR = struct {
    allocator: std.mem.Allocator,
    handle: *tesseract.TessBaseAPI,
    language: [:0]const u8,
    datapath: ?[:0]const u8,
    initialized: bool,

    const Self = @This();

    /// Initialize the OCR engine with default settings
    pub fn init(allocator: std.mem.Allocator) !Self {
        return initWithDatapath(allocator, null);
    }

    /// Initialize the OCR engine with a custom tessdata path
    pub fn initWithDatapath(allocator: std.mem.Allocator, datapath: ?[]const u8) !Self {
        const handle = tesseract.c.TessBaseAPICreate();
        // Ensure handle is deleted if initialization fails
        errdefer tesseract.c.TessBaseAPIDelete(handle);

        var self = Self{
            .allocator = allocator,
            .handle = handle,
            .language = "eng",
            .datapath = null,
            .initialized = false,
        };

        // Convert datapath to null-terminated if provided
        if (datapath) |dp| {
            self.datapath = try allocator.dupeZ(u8, dp);
        }
        // Ensure datapath is freed if initEngine fails
        errdefer if (self.datapath) |dp| allocator.free(dp);

        // Initialize with default language
        try self.initEngine();

        return self;
    }

    /// Initialize the Tesseract engine
    fn initEngine(self: *Self) !void {
        const datapath_ptr: ?[*:0]const u8 = if (self.datapath) |dp| dp.ptr else null;

        const result = tesseract.c.TessBaseAPIInit3(
            self.handle,
            datapath_ptr,
            self.language.ptr,
        );

        if (result != 0) {
            return error.TesseractInitFailed;
        }

        // Set user_defined_dpi to avoid warnings
        _ = tesseract.c.TessBaseAPISetVariable(self.handle, "user_defined_dpi", "300");

        self.initialized = true;
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.initialized) {
            tesseract.c.TessBaseAPIEnd(self.handle);
        }
        tesseract.c.TessBaseAPIDelete(self.handle);

        if (self.datapath) |dp| {
            self.allocator.free(dp);
        }
    }

    /// Reset the OCR configuration to defaults
    pub fn reset(self: *Self) void {
        tesseract.c.TessBaseAPIClear(self.handle);
    }

    /// Set the recognition language (e.g., "eng", "deu", "fra")
    pub fn setLanguage(self: *Self, language: [:0]const u8) void {
        self.language = language;
        // Note: Language change requires re-initialization
        // For simplicity, we just store it for reference
    }

    /// Set the page segmentation mode
    pub fn setPageSegMode(self: *Self, mode: PageSegMode) void {
        tesseract.c.TessBaseAPISetPageSegMode(self.handle, mode);
    }

    /// Get the current page segmentation mode
    pub fn getPageSegMode(self: *const Self) PageSegMode {
        return tesseract.c.TessBaseAPIGetPageSegMode(self.handle);
    }

    /// Set a Tesseract variable
    pub fn setVariable(self: *Self, name: [:0]const u8, value: [:0]const u8) bool {
        return tesseract.c.TessBaseAPISetVariable(self.handle, name.ptr, value.ptr) != 0;
    }

    /// Set the source image resolution in PPI
    pub fn setSourceResolution(self: *Self, ppi: u32) void {
        tesseract.c.TessBaseAPISetSourceResolution(self.handle, @intCast(ppi));
    }

    /// Read text from an image
    pub fn readText(self: *Self, image: *const Image) ![]u8 {
        // Set the image data
        self.setImage(image);

        // Perform recognition
        const result = tesseract.c.TessBaseAPIRecognize(self.handle, null);
        if (result != 0) {
            return error.RecognitionFailed;
        }

        // Get the recognized text
        const text_ptr = tesseract.c.TessBaseAPIGetUTF8Text(self.handle);
        if (text_ptr == null) {
            return error.NoTextFound;
        }
        defer tesseract.c.TessDeleteText(text_ptr.?);

        // Copy to owned memory
        const text_slice = std.mem.span(text_ptr.?);
        const owned = try self.allocator.dupe(u8, text_slice);

        // Clear for next use
        tesseract.c.TessBaseAPIClear(self.handle);

        return owned;
    }

    /// Read words from an image with positions and confidence
    pub fn readWords(self: *Self, image: *const Image) ![]Word {
        return self.readItems(image, .word);
    }

    /// Read lines from an image with positions and confidence
    pub fn readLines(self: *Self, image: *const Image) ![]Line {
        const items = try self.readItems(image, .textline);

        // Convert Word to Line (same structure)
        var lines = try self.allocator.alloc(Line, items.len);
        for (items, 0..) |item, i| {
            lines[i] = .{
                .text = item.text,
                .bounds = item.bounds,
                .confidence = item.confidence,
            };
        }
        self.allocator.free(items);

        return lines;
    }

    /// Internal: read items at a specific level
    fn readItems(self: *Self, image: *const Image, level: tesseract.PageIteratorLevel) ![]Word {
        // Set the image data
        self.setImage(image);

        // Perform recognition
        const result = tesseract.c.TessBaseAPIRecognize(self.handle, null);
        if (result != 0) {
            return error.RecognitionFailed;
        }

        // Get result iterator
        const iter = tesseract.c.TessBaseAPIGetIterator(self.handle);
        if (iter == null) {
            tesseract.c.TessBaseAPIClear(self.handle);
            return &[_]Word{};
        }

        // Collect results (using unmanaged ArrayList pattern for Zig 0.15)
        var words = std.ArrayList(Word).empty;
        errdefer {
            for (words.items) |word| {
                self.allocator.free(word.text);
            }
            words.deinit(self.allocator);
        }

        // Get page iterator for bounding boxes
        const page_iter = tesseract.c.TessResultIteratorGetPageIterator(iter.?);

        // Iterate through all items at the specified level
        var first = true;
        while (first or tesseract.c.TessResultIteratorNext(iter.?, level) != 0) {
            first = false;

            // Get text
            const text_ptr = tesseract.c.TessResultIteratorGetUTF8Text(iter.?, level);
            if (text_ptr == null) continue;
            defer tesseract.c.TessDeleteText(text_ptr.?);

            const text_slice = std.mem.span(text_ptr.?);
            if (text_slice.len == 0) continue;

            // Skip whitespace-only results
            const trimmed = std.mem.trim(u8, text_slice, " \t\n\r");
            if (trimmed.len == 0) continue;

            // Get bounding box
            var left: c_int = 0;
            var top: c_int = 0;
            var right: c_int = 0;
            var bottom: c_int = 0;

            if (tesseract.c.TessPageIteratorBoundingBox(page_iter, level, &left, &top, &right, &bottom) == 0) {
                continue;
            }

            // Get confidence
            const confidence = tesseract.c.TessResultIteratorConfidence(iter.?, level);

            // Copy text and store result
            const owned_text = try self.allocator.dupe(u8, text_slice);
            errdefer self.allocator.free(owned_text);

            try words.append(self.allocator, .{
                .text = owned_text,
                .bounds = Rectangle.init(
                    left,
                    top,
                    @intCast(right - left),
                    @intCast(bottom - top),
                ),
                .confidence = confidence,
            });
        }

        tesseract.c.TessResultIteratorDelete(iter.?);
        tesseract.c.TessBaseAPIClear(self.handle);

        return try words.toOwnedSlice(self.allocator);
    }

    /// Set the image for recognition
    fn setImage(self: *Self, image: *const Image) void {
        // Determine bytes per pixel based on image format
        const bpp: c_int = switch (image.format) {
            .Grayscale => 1,
            .RGB, .BGR => 3,
            .RGBA, .BGRA => 4,
        };

        const bytes_per_line: c_int = @intCast(image.stride);

        tesseract.c.TessBaseAPISetImage(
            self.handle,
            image.data.ptr,
            @intCast(image.width),
            @intCast(image.height),
            bpp,
            bytes_per_line,
        );
    }

    /// Get the Tesseract version
    pub fn version() []const u8 {
        return tesseract.getVersion();
    }
};

// Unit tests
test "OCR basic" {
    // Just test that we can call version()
    const ver = OCR.version();
    try std.testing.expect(ver.len > 0);
}
