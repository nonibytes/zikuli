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

Phase 4: OpenCV Template Matching (completed)

Next: Phase 5: Mouse control via XTest

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

## Discovered Constraints

- X11 only (no Wayland support initially)
- OpenCV required for template matching
- Tesseract required for OCR
- OpenCV 4.x C API headers require C++11 (created C++ wrapper to solve)
- Zig 0.15 deprecated `std.io.getStdOut()` - use `std.fs.File.stdout().deprecatedWriter()`
- Zig 0.15 strict about parameter shadowing - rename parameters if they shadow other names

## User Preferences

- Validation-driven development
- Small incremental commits
- Paranoid code review after each phase
