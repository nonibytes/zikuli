//! Low-level Tesseract C API bindings
//!
//! This module provides Zig bindings to the Tesseract OCR library's C API.
//! The bindings closely follow the capi.h definitions from Tesseract.

const std = @import("std");

// Opaque types from Tesseract C API
pub const TessBaseAPI = opaque {};
pub const TessResultIterator = opaque {};
pub const TessPageIterator = opaque {};
pub const TessChoiceIterator = opaque {};
pub const ETEXT_DESC = opaque {};
pub const Pix = opaque {};
pub const Boxa = opaque {};
pub const Pixa = opaque {};

/// OCR Engine Mode (matches TessOcrEngineMode from capi.h)
pub const OcrEngineMode = enum(c_int) {
    /// Tesseract Legacy only
    tesseract_only = 0,
    /// LSTM only
    lstm_only = 1,
    /// LSTM + Legacy combined
    tesseract_lstm_combined = 2,
    /// Default, based on what is available
    default = 3,
};

/// Page Segmentation Mode (matches TessPageSegMode from capi.h)
pub const PageSegMode = enum(c_int) {
    /// Orientation and script detection only
    osd_only = 0,
    /// Automatic page segmentation with OSD
    auto_osd = 1,
    /// Automatic page segmentation, but no OSD, or OCR
    auto_only = 2,
    /// Fully automatic page segmentation, but no OSD (default)
    auto = 3,
    /// Assume a single column of text of variable sizes
    single_column = 4,
    /// Assume a single uniform block of vertically aligned text
    single_block_vert_text = 5,
    /// Assume a single uniform block of text
    single_block = 6,
    /// Treat the image as a single text line
    single_line = 7,
    /// Treat the image as a single word
    single_word = 8,
    /// Treat the image as a single word in a circle
    circle_word = 9,
    /// Treat the image as a single character
    single_char = 10,
    /// Sparse text. Find as much text as possible in no particular order
    sparse_text = 11,
    /// Sparse text with OSD
    sparse_text_osd = 12,
    /// Raw line. Treat as single text line, bypassing Tesseract-specific hacks
    raw_line = 13,
};

/// Page Iterator Level (matches TessPageIteratorLevel from capi.h)
pub const PageIteratorLevel = enum(c_int) {
    /// Block of text
    block = 0,
    /// Paragraph
    para = 1,
    /// Text line
    textline = 2,
    /// Word
    word = 3,
    /// Symbol (character)
    symbol = 4,
};

/// Tesseract C API function bindings
pub const c = struct {
    // General functions
    pub extern fn TessVersion() [*:0]const u8;
    pub extern fn TessDeleteText(text: [*:0]const u8) void;
    pub extern fn TessDeleteTextArray(arr: [*c][*:0]u8) void;
    pub extern fn TessDeleteIntArray(arr: [*c]const c_int) void;

    // Base API functions
    pub extern fn TessBaseAPICreate() *TessBaseAPI;
    pub extern fn TessBaseAPIDelete(handle: *TessBaseAPI) void;

    pub extern fn TessBaseAPIInit3(
        handle: *TessBaseAPI,
        datapath: ?[*:0]const u8,
        language: [*:0]const u8,
    ) c_int;

    pub extern fn TessBaseAPIInit2(
        handle: *TessBaseAPI,
        datapath: ?[*:0]const u8,
        language: [*:0]const u8,
        oem: OcrEngineMode,
    ) c_int;

    pub extern fn TessBaseAPISetPageSegMode(handle: *TessBaseAPI, mode: PageSegMode) void;
    pub extern fn TessBaseAPIGetPageSegMode(handle: *const TessBaseAPI) PageSegMode;

    pub extern fn TessBaseAPISetVariable(
        handle: *TessBaseAPI,
        name: [*:0]const u8,
        value: [*:0]const u8,
    ) c_int;

    pub extern fn TessBaseAPISetImage(
        handle: *TessBaseAPI,
        imagedata: [*]const u8,
        width: c_int,
        height: c_int,
        bytes_per_pixel: c_int,
        bytes_per_line: c_int,
    ) void;

    pub extern fn TessBaseAPISetImage2(handle: *TessBaseAPI, pix: *Pix) void;

    pub extern fn TessBaseAPISetSourceResolution(handle: *TessBaseAPI, ppi: c_int) void;

    pub extern fn TessBaseAPISetRectangle(
        handle: *TessBaseAPI,
        left: c_int,
        top: c_int,
        width: c_int,
        height: c_int,
    ) void;

    pub extern fn TessBaseAPIRecognize(handle: *TessBaseAPI, monitor: ?*ETEXT_DESC) c_int;

    pub extern fn TessBaseAPIGetUTF8Text(handle: *TessBaseAPI) ?[*:0]u8;

    pub extern fn TessBaseAPIMeanTextConf(handle: *TessBaseAPI) c_int;

    pub extern fn TessBaseAPIAllWordConfidences(handle: *TessBaseAPI) ?[*]c_int;

    pub extern fn TessBaseAPIClear(handle: *TessBaseAPI) void;

    pub extern fn TessBaseAPIEnd(handle: *TessBaseAPI) void;

    pub extern fn TessBaseAPIGetIterator(handle: *TessBaseAPI) ?*TessResultIterator;

    // Result Iterator functions
    pub extern fn TessResultIteratorDelete(handle: *TessResultIterator) void;

    pub extern fn TessResultIteratorNext(
        handle: *TessResultIterator,
        level: PageIteratorLevel,
    ) c_int;

    pub extern fn TessResultIteratorGetUTF8Text(
        handle: *const TessResultIterator,
        level: PageIteratorLevel,
    ) ?[*:0]u8;

    pub extern fn TessResultIteratorConfidence(
        handle: *const TessResultIterator,
        level: PageIteratorLevel,
    ) f32;

    pub extern fn TessResultIteratorGetPageIterator(
        handle: *TessResultIterator,
    ) *TessPageIterator;

    // Page Iterator functions
    pub extern fn TessPageIteratorDelete(handle: *TessPageIterator) void;

    pub extern fn TessPageIteratorBegin(handle: *TessPageIterator) void;

    pub extern fn TessPageIteratorNext(
        handle: *TessPageIterator,
        level: PageIteratorLevel,
    ) c_int;

    pub extern fn TessPageIteratorBoundingBox(
        handle: *const TessPageIterator,
        level: PageIteratorLevel,
        left: *c_int,
        top: *c_int,
        right: *c_int,
        bottom: *c_int,
    ) c_int;

    pub extern fn TessPageIteratorIsAtBeginningOf(
        handle: *const TessPageIterator,
        level: PageIteratorLevel,
    ) c_int;

    pub extern fn TessPageIteratorIsAtFinalElement(
        handle: *const TessPageIterator,
        level: PageIteratorLevel,
        element: PageIteratorLevel,
    ) c_int;
};

/// Get the Tesseract version string
pub fn getVersion() []const u8 {
    const ver_ptr = c.TessVersion();
    return std.mem.span(ver_ptr);
}

/// Helper to convert C string to Zig slice
pub fn toSlice(c_str: ?[*:0]const u8) ?[]const u8 {
    if (c_str) |ptr| {
        return std.mem.span(ptr);
    }
    return null;
}

test "tesseract version" {
    const version = getVersion();
    try std.testing.expect(version.len > 0);
}
