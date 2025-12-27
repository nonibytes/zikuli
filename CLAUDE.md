# Zikuli Development Notes

## Project Facts

- **Project**: Zikuli - SikuliX re-implementation in Zig
- **Zig Version**: 0.15.2
- **Platform**: Linux (X11 only)
- **License**: MIT (matching SikuliX)

## Source Code References

- SikuliX1 (Java): `/tmp/temp-github-repos/SikuliX1/`
- sikuli-original (C++): `/tmp/temp-github-repos/sikuli-original/sikuli-script/src/main/native/`

## Key Algorithm Constants

| Constant | Value | Source |
|----------|-------|--------|
| MIN_SIMILARITY | 0.7 | Settings.java:42 |
| MIN_TARGET_DIMENSION | 12 | finder.h:11 |
| REMATCH_THRESHOLD | 0.9 | finder.h:15 |
| ERASE_MARGIN | targetSize/3 | pyramid-template-matcher.cpp:156 |
| PLAIN_COLOR_STDDEV | 1e-5 | pyramid-template-matcher.h:64 |

## Current Phase

**All Phases Complete + Multi-Monitor Support**

Completed Phases:
- Phase 0-4: Core types, geometry, X11 capture, OpenCV template matching
- Phase 5: Mouse control via XTest (112 tests passed)
- Phase 6: Keyboard control via XTest (120 tests passed)
- Phase 7: Region operations integration (11 tests passed)
- Phase 8: OCR with Tesseract (9 tests passed, 400 words detected)
- Phase 9: High-level API and examples (4 examples working)
- Phase 10: Real-world automation examples (3 examples verified)
- Multi-Monitor: XRandR support for per-monitor capture (like SikuliX)

## Decisions

- OCR: Include in initial implementation
- Display Server: X11 only
- Test Data: Synthetic images
- Still-there optimization: Implement

## Build Commands

```bash
# Build
~/.zig/zig build

# Test
~/.zig/zig build test

# Run
~/.zig/zig build run
```

## Open Questions

None currently.

## Multi-Monitor Support

- **XRandR** enumerates individual monitors (like SikuliX's ScreenDevice.java)
- `Screen.primary()` / `Screen.get(0)` returns primary monitor bounds only (e.g., 1920x1080)
- `Screen.get(1)` returns second monitor bounds (e.g., 1920x1080 at x=1920)
- `Screen.virtual()` returns combined virtual screen (e.g., 3840x1080)
- `Screen.capture()` now captures only that monitor's region, not the full virtual screen
- `Screen.getMonitorCount()` returns number of connected monitors
- Test: `zig build test-multimonitor` verifies XRandR enumeration

## Discovered Constraints

- X11 only (no Wayland support initially)
- OpenCV required for template matching
- Tesseract required for OCR
- XRandR required for multi-monitor support on Linux
- OpenCV 4.x C API headers require C++11 (created C++ wrapper to solve)
- Zig 0.15 deprecated `std.io.getStdOut()` - use `std.fs.File.stdout().deprecatedWriter()`
- Zig 0.15 strict about parameter shadowing - rename parameters if they shadow other names
- Zig 0.15 `std.Thread.sleep` replaces `std.time.sleep` in executable contexts
- Zig 0.15 `std.ArrayList(T)` is now unmanaged: use `.empty` instead of `.init(allocator)`, pass allocator to `append()`, `deinit()`, `toOwnedSlice()`
- OCR struggles with white text on colored backgrounds - use dark text on light buttons for better recognition

## User Preferences

- Validation-driven development
- Small incremental commits
- Paranoid code review after each phase