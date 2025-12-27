# Zikuli

A faithful re-implementation of [SikuliX](https://sikulix.github.io/) in idiomatic Zig.

Visual GUI automation using image recognition - find patterns on screen, click, type, and automate any application.

## Features

- Screen capture via X11/XCB
- Image pattern matching via OpenCV
- Mouse and keyboard control via XTest
- OCR text recognition via Tesseract
- No garbage collection, explicit memory management
- Comptime where possible

## Requirements

- Zig 0.15.2+
- Linux with X11
- libxcb, libxcb-shm, libxcb-image, libxcb-xtest
- OpenCV 4.x
- Tesseract (optional, for OCR)

## Installation

```bash
# Install system dependencies (Ubuntu/Debian)
sudo apt-get install \
    libxcb1-dev \
    libxcb-shm0-dev \
    libxcb-image0-dev \
    libxcb-xtest0-dev \
    libopencv-dev \
    libtesseract-dev

# Build
zig build

# Run
./zig-out/bin/zikuli
```

## Usage

### Library

```zig
const zikuli = @import("zikuli");

pub fn main() !void {
    var screen = try zikuli.Screen.primary();
    defer screen.deinit();

    // Find and click a button
    const match = try screen.region().find("button.png");
    try match.click();

    // Wait for dialog to appear
    _ = try screen.region().wait("dialog.png", 5.0);

    // Type text
    try zikuli.Keyboard.type_text("Hello, World!");
}
```

### CLI

```bash
# Capture screenshot
zikuli capture --output screenshot.png

# Find pattern on screen
zikuli find button.png

# Click on pattern
zikuli click button.png

# Type text
zikuli type "Hello, World!"
```

## Development

```bash
# Build
zig build

# Run tests
zig build test

# Run
zig build run
```

## Status

Work in progress. See [docs/IMPLEMENTATION_PLAN.md](docs/IMPLEMENTATION_PLAN.md) for roadmap.

## License

MIT
