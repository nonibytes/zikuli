// OpenCV wrapper implementation for Zikuli
// Compiled as C++ but provides a C API

#include "opencv_wrapper.h"
#include <opencv2/core.hpp>
#include <opencv2/imgproc.hpp>

// The opaque handle is just a cv::Mat pointer
struct ZikuliMat {
    cv::Mat mat;
};

extern "C" {

ZikuliMatHandle zikuli_mat_create(int32_t rows, int32_t cols, int32_t type) {
    try {
        ZikuliMat* wrapper = new ZikuliMat();
        wrapper->mat = cv::Mat(rows, cols, type);
        return wrapper;
    } catch (...) {
        return nullptr;
    }
}

ZikuliMatHandle zikuli_mat_create_with_data(int32_t rows, int32_t cols, int32_t type,
                                            void* data, int32_t step) {
    try {
        ZikuliMat* wrapper = new ZikuliMat();
        // Clone the data so we own it
        cv::Mat temp(rows, cols, type, data, step);
        wrapper->mat = temp.clone();
        return wrapper;
    } catch (...) {
        return nullptr;
    }
}

void zikuli_mat_release(ZikuliMatHandle mat) {
    if (mat) {
        delete mat;
    }
}

int32_t zikuli_mat_rows(ZikuliMatHandle mat) {
    return mat ? mat->mat.rows : 0;
}

int32_t zikuli_mat_cols(ZikuliMatHandle mat) {
    return mat ? mat->mat.cols : 0;
}

void* zikuli_mat_data(ZikuliMatHandle mat) {
    return mat ? mat->mat.data : nullptr;
}

int32_t zikuli_mat_step(ZikuliMatHandle mat) {
    return mat ? static_cast<int32_t>(mat->mat.step[0]) : 0;
}

int zikuli_match_template(ZikuliMatHandle image, ZikuliMatHandle templ,
                          ZikuliMatHandle result, ZikuliMatchMethod method) {
    if (!image || !templ || !result) {
        return -1;
    }

    try {
        cv::matchTemplate(image->mat, templ->mat, result->mat, static_cast<int>(method));
        return 0;
    } catch (...) {
        return -1;
    }
}

int zikuli_min_max_loc(ZikuliMatHandle src, ZikuliMinMaxResult* result) {
    if (!src || !result) {
        return -1;
    }

    try {
        cv::Point min_loc, max_loc;
        cv::minMaxLoc(src->mat, &result->min_val, &result->max_val, &min_loc, &max_loc);
        result->min_loc.x = min_loc.x;
        result->min_loc.y = min_loc.y;
        result->max_loc.x = max_loc.x;
        result->max_loc.y = max_loc.y;
        return 0;
    } catch (...) {
        return -1;
    }
}

int zikuli_mat_set_region(ZikuliMatHandle mat, int32_t x, int32_t y,
                          int32_t width, int32_t height, double value) {
    if (!mat) {
        return -1;
    }

    // Explicit bounds checking before creating ROI
    if (x < 0 || y < 0 || width <= 0 || height <= 0) {
        return -1;
    }
    if (x + width > mat->mat.cols || y + height > mat->mat.rows) {
        return -1;
    }

    try {
        cv::Rect roi(x, y, width, height);
        mat->mat(roi).setTo(cv::Scalar(value));
        return 0;
    } catch (...) {
        return -1;
    }
}

} // extern "C"
