//! OpenCV wrapper bindings for Zikuli
//!
//! Provides Zig bindings to the OpenCV C wrapper for template matching.
//! The wrapper is a C++ library that exposes a pure C API.

const std = @import("std");

// Import the C wrapper header
pub const c = @cImport({
    @cInclude("opencv_wrapper.h");
});

/// Template matching methods (from OpenCV)
pub const MatchMethod = enum(c_int) {
    /// Sum of squared differences
    TM_SQDIFF = c.ZIKULI_TM_SQDIFF,
    /// Normalized sum of squared differences
    TM_SQDIFF_NORMED = c.ZIKULI_TM_SQDIFF_NORMED,
    /// Cross correlation
    TM_CCORR = c.ZIKULI_TM_CCORR,
    /// Normalized cross correlation
    TM_CCORR_NORMED = c.ZIKULI_TM_CCORR_NORMED,
    /// Correlation coefficient
    TM_CCOEFF = c.ZIKULI_TM_CCOEFF,
    /// Normalized correlation coefficient (best for general use)
    TM_CCOEFF_NORMED = c.ZIKULI_TM_CCOEFF_NORMED,
};

/// Matrix type constants
pub const MatType = struct {
    pub const CV_8UC1 = c.ZIKULI_CV_8UC1;
    pub const CV_8UC3 = c.ZIKULI_CV_8UC3;
    pub const CV_8UC4 = c.ZIKULI_CV_8UC4;
    pub const CV_32FC1 = c.ZIKULI_CV_32FC1;
};

/// Point structure
pub const Point = c.ZikuliPoint;

/// MinMaxLoc result
pub const MinMaxResult = c.ZikuliMinMaxResult;

/// Opaque matrix handle
pub const Mat = c.ZikuliMatHandle;

/// Create a new matrix
pub fn createMat(rows: c_int, cols: c_int, mat_type: c_int) ?Mat {
    return c.zikuli_mat_create(rows, cols, mat_type);
}

/// Create a matrix with existing data
pub fn createMatWithData(rows: c_int, cols: c_int, mat_type: c_int, data: ?*anyopaque, step: c_int) ?Mat {
    return c.zikuli_mat_create_with_data(rows, cols, mat_type, data, step);
}

/// Release a matrix
pub fn releaseMat(mat: *?Mat) void {
    if (mat.*) |m| {
        c.zikuli_mat_release(m);
        mat.* = null;
    }
}

/// Get matrix rows
pub fn getRows(mat: Mat) c_int {
    return c.zikuli_mat_rows(mat);
}

/// Get matrix columns
pub fn getCols(mat: Mat) c_int {
    return c.zikuli_mat_cols(mat);
}

/// Get matrix data pointer
pub fn getData(mat: Mat) ?*anyopaque {
    return c.zikuli_mat_data(mat);
}

/// Get matrix step
pub fn getStep(mat: Mat) c_int {
    return c.zikuli_mat_step(mat);
}

/// Perform template matching
/// result must be pre-allocated with size (W-w+1) x (H-h+1) and type CV_32FC1
pub fn matchTemplate(image: Mat, templ: Mat, result: Mat, method: MatchMethod) bool {
    // Cast our enum to the C enum type (which Zig translates as c_uint)
    return c.zikuli_match_template(image, templ, result, @as(c_uint, @intCast(@intFromEnum(method)))) == 0;
}

/// Find minimum and maximum values and their locations in a matrix
pub fn minMaxLoc(src: Mat) ?MinMaxResult {
    var result: MinMaxResult = undefined;
    if (c.zikuli_min_max_loc(src, &result) == 0) {
        return result;
    }
    return null;
}

/// Set a region of a matrix to a specific value (for match suppression)
pub fn setRegion(mat: Mat, x: c_int, y: c_int, width: c_int, height: c_int, value: f64) bool {
    return c.zikuli_mat_set_region(mat, x, y, width, height, value) == 0;
}

// ============================================================================
// TESTS
// ============================================================================

test "OpenCV bindings: compile check" {
    // Verify the bindings compile
    _ = MatchMethod.TM_CCOEFF_NORMED;
    _ = MatType.CV_8UC4;
}

test "OpenCV bindings: create and release matrix" {
    // Note: These tests only work if the OpenCV wrapper library is linked
    // In unit test mode without the library, we just verify compilation
    const mat = createMat(10, 10, MatType.CV_32FC1);
    if (mat) |m| {
        try std.testing.expectEqual(@as(c_int, 10), getRows(m));
        try std.testing.expectEqual(@as(c_int, 10), getCols(m));

        // Release
        var mat_ptr: ?Mat = m;
        releaseMat(&mat_ptr);
        try std.testing.expect(mat_ptr == null);
    }
}
