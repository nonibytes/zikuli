// OpenCV wrapper for Zikuli
// This provides a pure C interface to OpenCV's template matching functions.
// The implementation is in C++ but exposes a C API.

#ifndef ZIKULI_OPENCV_WRAPPER_H
#define ZIKULI_OPENCV_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

// Opaque handle types
typedef struct ZikuliMat* ZikuliMatHandle;

// Template matching methods
typedef enum {
    ZIKULI_TM_SQDIFF = 0,
    ZIKULI_TM_SQDIFF_NORMED = 1,
    ZIKULI_TM_CCORR = 2,
    ZIKULI_TM_CCORR_NORMED = 3,
    ZIKULI_TM_CCOEFF = 4,
    ZIKULI_TM_CCOEFF_NORMED = 5
} ZikuliMatchMethod;

// Point structure
typedef struct {
    int32_t x;
    int32_t y;
} ZikuliPoint;

// MinMaxLoc result
typedef struct {
    double min_val;
    double max_val;
    ZikuliPoint min_loc;
    ZikuliPoint max_loc;
} ZikuliMinMaxResult;

// Matrix creation/destruction
ZikuliMatHandle zikuli_mat_create(int32_t rows, int32_t cols, int32_t type);
ZikuliMatHandle zikuli_mat_create_with_data(int32_t rows, int32_t cols, int32_t type,
                                            void* data, int32_t step);
void zikuli_mat_release(ZikuliMatHandle mat);

// Matrix info
int32_t zikuli_mat_rows(ZikuliMatHandle mat);
int32_t zikuli_mat_cols(ZikuliMatHandle mat);
void* zikuli_mat_data(ZikuliMatHandle mat);
int32_t zikuli_mat_step(ZikuliMatHandle mat);

// Template matching
int zikuli_match_template(ZikuliMatHandle image, ZikuliMatHandle templ,
                          ZikuliMatHandle result, ZikuliMatchMethod method);

// Find min/max location
int zikuli_min_max_loc(ZikuliMatHandle src, ZikuliMinMaxResult* result);

// Set value in matrix (for suppression)
int zikuli_mat_set_region(ZikuliMatHandle mat, int32_t x, int32_t y,
                          int32_t width, int32_t height, double value);

// Matrix type constants
#define ZIKULI_CV_8UC1  0
#define ZIKULI_CV_8UC3  16
#define ZIKULI_CV_8UC4  24
#define ZIKULI_CV_32FC1 5

#ifdef __cplusplus
}
#endif

#endif // ZIKULI_OPENCV_WRAPPER_H
