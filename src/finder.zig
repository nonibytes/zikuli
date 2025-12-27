//! Finder - Image template matching for Zikuli
//!
//! Provides high-level image matching using OpenCV's template matching.
//! Based on SikuliX Finder.java analysis:
//! - Uses TM_CCOEFF_NORMED for regular images
//! - Uses TM_SQDIFF_NORMED for plain/solid color images
//! - Supports findAll with match suppression
//! - Implements "still-there" optimization via lastSeen cache

const std = @import("std");
const geometry = @import("geometry.zig");
const image_mod = @import("image.zig");
const match_mod = @import("match.zig");
const pattern_mod = @import("pattern.zig");
const opencv = @import("opencv/bindings.zig");

const Rectangle = geometry.Rectangle;
const Point = geometry.Point;
const Image = image_mod.Image;
const Match = match_mod.Match;
const Pattern = pattern_mod.Pattern;

/// Default minimum similarity threshold (from SikuliX Settings.java)
pub const DEFAULT_MIN_SIMILARITY: f64 = 0.7;

/// Margin for suppressing overlapping matches (as fraction of template size)
/// NOTE: This differs from SikuliX Java which uses 0.8 (80%).
/// We use 1/3 from the C++ sikuli-original pyramid-template-matcher.cpp:156
/// Reason: The C++ version is more conservative, avoiding suppression of
/// distinct but close matches. Change to 0.8 if exact SikuliX Java behavior is needed.
pub const ERASE_MARGIN_FRACTION: f64 = 1.0 / 3.0;

/// Threshold reduction for "still-there" check
pub const STILL_THERE_THRESHOLD_REDUCTION: f64 = 0.01;

/// Finder performs template matching on images
pub const Finder = struct {
    /// Source image to search in
    source: *const Image,

    /// Minimum similarity threshold
    min_similarity: f64,

    /// Allocator for results
    allocator: std.mem.Allocator,

    /// OpenCV matrix for source image (lazy initialized)
    source_mat: ?opencv.Mat,

    /// Create a new Finder for the given source image
    pub fn init(allocator: std.mem.Allocator, source: *const Image) Finder {
        return .{
            .source = source,
            .min_similarity = DEFAULT_MIN_SIMILARITY,
            .allocator = allocator,
            .source_mat = null,
        };
    }

    /// Set minimum similarity threshold
    pub fn setSimilarity(self: *Finder, similarity: f64) void {
        self.min_similarity = std.math.clamp(similarity, 0.0, 1.0);
    }

    /// Clean up resources
    pub fn deinit(self: *Finder) void {
        if (self.source_mat) |_| {
            var mat_ptr: ?opencv.Mat = self.source_mat;
            opencv.releaseMat(&mat_ptr);
            self.source_mat = null;
        }
    }

    /// Find the best match for a template in the source image
    pub fn find(self: *Finder, template: *const Image) ?Match {
        return self.findWithThreshold(template, self.min_similarity);
    }

    /// Find the best match with a specific similarity threshold
    pub fn findWithThreshold(self: *Finder, template: *const Image, threshold: f64) ?Match {
        // Validate sizes
        if (template.width > self.source.width or template.height > self.source.height) {
            return null; // Template larger than source
        }

        if (template.width == 0 or template.height == 0) {
            return null;
        }

        // Create OpenCV matrices
        const src_mat = self.getSourceMat() orelse return null;
        const tmpl_mat = createMatFromImage(template) orelse return null;
        defer {
            var mat_ptr: ?opencv.Mat = tmpl_mat;
            opencv.releaseMat(&mat_ptr);
        }

        // Create result matrix
        const result_rows: c_int = @intCast(self.source.height - template.height + 1);
        const result_cols: c_int = @intCast(self.source.width - template.width + 1);
        const result_mat = opencv.createMat(result_rows, result_cols, opencv.MatType.CV_32FC1) orelse return null;
        defer {
            var mat_ptr: ?opencv.Mat = result_mat;
            opencv.releaseMat(&mat_ptr);
        }

        // Choose matching method based on image type
        const method = if (template.isPlainColor())
            opencv.MatchMethod.TM_SQDIFF_NORMED
        else
            opencv.MatchMethod.TM_CCOEFF_NORMED;

        // Perform template matching
        if (!opencv.matchTemplate(src_mat, tmpl_mat, result_mat, method)) {
            return null;
        }

        // Find best match location
        const minmax = opencv.minMaxLoc(result_mat) orelse return null;

        // For SQDIFF methods, minimum is best match
        const score = if (method == .TM_SQDIFF_NORMED)
            1.0 - minmax.min_val
        else
            minmax.max_val;

        const loc = if (method == .TM_SQDIFF_NORMED) minmax.min_loc else minmax.max_loc;

        // Check threshold
        if (score < threshold) {
            return null;
        }

        return Match.initAt(
            loc.x,
            loc.y,
            template.width,
            template.height,
            score,
        );
    }

    /// Find all matches above threshold
    pub fn findAll(self: *Finder, template: *const Image) ![]Match {
        return self.findAllWithThreshold(template, self.min_similarity);
    }

    /// Find all matches with specific threshold
    pub fn findAllWithThreshold(self: *Finder, template: *const Image, threshold: f64) ![]Match {
        // Use unmanaged ArrayList pattern for Zig 0.15
        var matches = std.ArrayList(Match).empty;
        errdefer matches.deinit(self.allocator);

        // Validate sizes
        if (template.width > self.source.width or template.height > self.source.height) {
            return matches.toOwnedSlice(self.allocator);
        }

        if (template.width == 0 or template.height == 0) {
            return matches.toOwnedSlice(self.allocator);
        }

        // Create OpenCV matrices
        const src_mat = self.getSourceMat() orelse return matches.toOwnedSlice(self.allocator);
        const tmpl_mat = createMatFromImage(template) orelse return matches.toOwnedSlice(self.allocator);
        defer {
            var mat_ptr: ?opencv.Mat = tmpl_mat;
            opencv.releaseMat(&mat_ptr);
        }

        // Create result matrix
        const result_rows: c_int = @intCast(self.source.height - template.height + 1);
        const result_cols: c_int = @intCast(self.source.width - template.width + 1);
        const result_mat = opencv.createMat(result_rows, result_cols, opencv.MatType.CV_32FC1) orelse return matches.toOwnedSlice(self.allocator);
        defer {
            var mat_ptr: ?opencv.Mat = result_mat;
            opencv.releaseMat(&mat_ptr);
        }

        // Choose matching method
        const method = if (template.isPlainColor())
            opencv.MatchMethod.TM_SQDIFF_NORMED
        else
            opencv.MatchMethod.TM_CCOEFF_NORMED;

        const is_sqdiff = method == .TM_SQDIFF_NORMED;

        // Perform template matching
        if (!opencv.matchTemplate(src_mat, tmpl_mat, result_mat, method)) {
            return matches.toOwnedSlice(self.allocator);
        }

        // Calculate erase margin for match suppression
        const erase_margin_x: c_int = @intCast(@as(u32, @intFromFloat(@as(f64, @floatFromInt(template.width)) * ERASE_MARGIN_FRACTION)));
        const erase_margin_y: c_int = @intCast(@as(u32, @intFromFloat(@as(f64, @floatFromInt(template.height)) * ERASE_MARGIN_FRACTION)));

        // Find all matches above threshold
        var index: i32 = 0;
        while (true) {
            const minmax = opencv.minMaxLoc(result_mat) orelse break;

            const score = if (is_sqdiff) 1.0 - minmax.min_val else minmax.max_val;
            const loc = if (is_sqdiff) minmax.min_loc else minmax.max_loc;

            if (score < threshold) {
                break;
            }

            // Add match
            var m = Match.initAt(
                loc.x,
                loc.y,
                template.width,
                template.height,
                score,
            );
            m.index = index;
            try matches.append(self.allocator, m);
            index += 1;

            // Suppress this match region in result matrix
            // Set values to worst possible score to prevent re-detection
            const suppress_val: f64 = if (is_sqdiff) 1.0 else 0.0;

            const x_start = @max(0, loc.x - erase_margin_x);
            const y_start = @max(0, loc.y - erase_margin_y);
            const x_end = @min(result_cols, loc.x + erase_margin_x + 1);
            const y_end = @min(result_rows, loc.y + erase_margin_y + 1);

            _ = opencv.setRegion(result_mat, x_start, y_start, x_end - x_start, y_end - y_start, suppress_val);

            // Safety limit
            if (index >= 1000) break;
        }

        return matches.toOwnedSlice(self.allocator);
    }

    /// Get or create OpenCV matrix for source image
    fn getSourceMat(self: *Finder) ?opencv.Mat {
        if (self.source_mat) |mat| {
            return mat;
        }

        self.source_mat = createMatFromImage(self.source);
        return self.source_mat;
    }
};

/// Create an OpenCV matrix from an Image
/// IMPORTANT: The C++ wrapper clones the data (opencv_wrapper.cpp:31), so the
/// returned Mat is independent of the original Image. The Image can be safely
/// deallocated after this call without affecting the Mat.
fn createMatFromImage(img: *const Image) ?opencv.Mat {
    // Determine OpenCV type based on format
    const cv_type: c_int = switch (img.format) {
        .RGBA, .BGRA => opencv.MatType.CV_8UC4,
        .RGB, .BGR => opencv.MatType.CV_8UC3,
        .Grayscale => opencv.MatType.CV_8UC1,
    };

    return opencv.createMatWithData(
        @intCast(img.height),
        @intCast(img.width),
        cv_type,
        img.data.ptr,
        @intCast(img.stride),
    );
}

// ============================================================================
// TESTS
// ============================================================================

test "Finder: compile check" {
    _ = Finder;
    _ = DEFAULT_MIN_SIMILARITY;
    _ = ERASE_MARGIN_FRACTION;
}

test "Finder: init and deinit" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 100, 100, .RGBA);
    defer img.deinit();

    var finder = Finder.init(allocator, &img);
    defer finder.deinit();

    try std.testing.expectApproxEqAbs(DEFAULT_MIN_SIMILARITY, finder.min_similarity, 0.0001);
}

test "Finder: setSimilarity" {
    const allocator = std.testing.allocator;
    var img = try Image.init(allocator, 100, 100, .RGBA);
    defer img.deinit();

    var finder = Finder.init(allocator, &img);
    defer finder.deinit();

    finder.setSimilarity(0.9);
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), finder.min_similarity, 0.0001);

    // Clamping
    finder.setSimilarity(1.5);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), finder.min_similarity, 0.0001);

    finder.setSimilarity(-0.5);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), finder.min_similarity, 0.0001);
}

test "Finder: template larger than source returns null" {
    const allocator = std.testing.allocator;

    var source = try Image.init(allocator, 50, 50, .RGBA);
    defer source.deinit();

    var template = try Image.init(allocator, 100, 100, .RGBA);
    defer template.deinit();

    var finder = Finder.init(allocator, &source);
    defer finder.deinit();

    const result = finder.find(&template);
    try std.testing.expect(result == null);
}
