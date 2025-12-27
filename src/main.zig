//! Zikuli CLI - Command-line interface for Zikuli visual automation
//!
//! This executable provides command-line access to all Zikuli functionality.
//! For library usage, import the 'zikuli' module directly.
//!
//! Commands:
//!   capture     Capture a screenshot
//!   click       Click at coordinates or on pattern
//!   move        Move mouse to coordinates
//!   type        Type text
//!   key         Press a key or key combo
//!   ocr         Read text from screen region
//!   find        Find an image pattern on screen
//!   drag        Drag from one point to another
//!   wheel       Scroll mouse wheel
//!   info        Display screen information
//!   pos         Show current mouse position

const std = @import("std");
const zikuli = @import("zikuli");

const Screen = zikuli.Screen;
const Mouse = zikuli.Mouse;
const Keyboard = zikuli.Keyboard;
const KeySym = zikuli.KeySym;
const KeyModifier = zikuli.KeyModifier;
const MouseButton = zikuli.MouseButton;
const OCR = zikuli.OCR;
const Image = zikuli.Image;
const Finder = zikuli.Finder;
const Rectangle = zikuli.Rectangle;
const Point = zikuli.Point;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const stdout = std.fs.File.stdout().deprecatedWriter();
    const stderr = std.fs.File.stderr().deprecatedWriter();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip program name
    _ = args.next();

    const command = args.next() orelse {
        try printHelp(stdout);
        return;
    };

    // Parse command
    if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "--help") or std.mem.eql(u8, command, "-h")) {
        try printHelp(stdout);
    } else if (std.mem.eql(u8, command, "version") or std.mem.eql(u8, command, "--version") or std.mem.eql(u8, command, "-v")) {
        try stdout.print("Zikuli {s}\n", .{zikuli.getVersion()});
    } else if (std.mem.eql(u8, command, "capture")) {
        try cmdCapture(allocator, &args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "click")) {
        try cmdClick(allocator, &args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "move")) {
        try cmdMove(&args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "type")) {
        try cmdType(&args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "key")) {
        try cmdKey(&args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "ocr")) {
        try cmdOcr(allocator, &args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "find")) {
        try cmdFind(allocator, &args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "drag")) {
        try cmdDrag(&args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "wheel")) {
        try cmdWheel(&args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "info")) {
        try cmdInfo(allocator, stdout);
    } else if (std.mem.eql(u8, command, "pos")) {
        try cmdPos(stdout);
    } else if (std.mem.eql(u8, command, "dclick")) {
        try cmdDoubleClick(allocator, &args, stdout, stderr);
    } else if (std.mem.eql(u8, command, "rclick")) {
        try cmdRightClick(allocator, &args, stdout, stderr);
    } else {
        try stderr.print("Unknown command: {s}\n\n", .{command});
        try printHelp(stderr);
    }
}

fn printHelp(writer: anytype) !void {
    try writer.print(
        \\
        \\  _____  _  _            _  _
        \\ |__  / (_)| | __ _   _ | |(_)
        \\   / /  | || |/ /| | | || || |
        \\  / /_  | ||   < | |_| || || |
        \\ /____| |_||_|\_\ \__,_||_||_|
        \\
        \\ Visual GUI Automation for Zig
        \\ Version: {s}
        \\
        \\ A faithful re-implementation of SikuliX.
        \\
        \\ Usage:
        \\   zikuli <command> [options]
        \\
        \\ Commands:
        \\   capture [options]       Capture screenshot
        \\     -o, --output <file>     Output file (default: /tmp/screenshot.png)
        \\     -x <x> -y <y> -w <w> -h <h>  Capture region
        \\
        \\   click <x> <y>           Click at coordinates
        \\   click --find <pattern>  Find pattern and click on it
        \\
        \\   dclick <x> <y>          Double-click at coordinates
        \\   rclick <x> <y>          Right-click at coordinates
        \\
        \\   move <x> <y>            Move mouse to coordinates
        \\     --smooth              Use smooth movement (default)
        \\     --instant             Instant movement
        \\
        \\   type <text>             Type text
        \\
        \\   key <keyname>           Press a key
        \\     Examples: enter, tab, escape, f1-f12, up, down, left, right
        \\     Modifiers: ctrl+c, alt+f4, shift+a, super+d
        \\
        \\   ocr [options]           Read text from screen
        \\     -x <x> -y <y> -w <w> -h <h>  Read from region
        \\     --words               Output word bounding boxes
        \\
        \\   find <pattern.png>      Find pattern on screen
        \\     --similarity <0.0-1.0>  Minimum similarity (default: 0.7)
        \\     --all                 Find all matches
        \\
        \\   drag <x1> <y1> <x2> <y2>  Drag from point to point
        \\
        \\   wheel <up|down> [steps]   Scroll wheel (default: 3 steps)
        \\
        \\   info                    Display screen information
        \\
        \\   pos                     Show current mouse position
        \\
        \\   version                 Show version information
        \\
        \\ Examples:
        \\   zikuli capture -o screen.png
        \\   zikuli click 500 300
        \\   zikuli move 100 100
        \\   zikuli type "Hello, World!"
        \\   zikuli key ctrl+s
        \\   zikuli ocr -x 100 -y 100 -w 200 -h 50
        \\   zikuli find button.png
        \\   zikuli drag 100 100 500 500
        \\   zikuli wheel down 5
        \\
        \\ For more information: https://github.com/nonibytes/zikuli
        \\
        \\
    , .{zikuli.getVersion()});
}

// ============================================================================
// Command Implementations
// ============================================================================

fn cmdCapture(allocator: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    var output_file: []const u8 = "/tmp/screenshot.png";
    var region_x: ?i32 = null;
    var region_y: ?i32 = null;
    var region_w: ?u32 = null;
    var region_h: ?u32 = null;

    // Parse options
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-o") or std.mem.eql(u8, arg, "--output")) {
            output_file = args.next() orelse {
                try stderr.print("Error: -o requires a file path\n", .{});
                return;
            };
        } else if (std.mem.eql(u8, arg, "-x")) {
            region_x = std.fmt.parseInt(i32, args.next() orelse "0", 10) catch 0;
        } else if (std.mem.eql(u8, arg, "-y")) {
            region_y = std.fmt.parseInt(i32, args.next() orelse "0", 10) catch 0;
        } else if (std.mem.eql(u8, arg, "-w")) {
            region_w = std.fmt.parseInt(u32, args.next() orelse "100", 10) catch 100;
        } else if (std.mem.eql(u8, arg, "-h")) {
            region_h = std.fmt.parseInt(u32, args.next() orelse "100", 10) catch 100;
        }
    }

    // Capture screen
    var screen = Screen.primary(allocator) catch |err| {
        try stderr.print("Error: Failed to connect to display: {}\n", .{err});
        return;
    };
    defer screen.deinit();

    // Capture full screen or region
    if (region_x != null and region_y != null and region_w != null and region_h != null) {
        const rect = Rectangle.init(region_x.?, region_y.?, region_w.?, region_h.?);
        var captured = screen.captureRegion(rect) catch |err| {
            try stderr.print("Error: Failed to capture region: {}\n", .{err});
            return;
        };
        defer captured.deinit();

        // Save to file
        var img = Image.fromCapture(allocator, captured) catch |err| {
            try stderr.print("Error: Failed to convert image: {}\n", .{err});
            return;
        };
        defer img.deinit();
        zikuli.image.savePng(&img, output_file) catch |err| {
            try stderr.print("Error: Failed to save image: {}\n", .{err});
            return;
        };
        try stdout.print("Captured region {d}x{d}+{d}+{d} to {s}\n", .{ region_w.?, region_h.?, region_x.?, region_y.?, output_file });
    } else {
        var captured = screen.capture() catch |err| {
            try stderr.print("Error: Failed to capture screen: {}\n", .{err});
            return;
        };
        defer captured.deinit();

        // Save to file
        var img = Image.fromCapture(allocator, captured) catch |err| {
            try stderr.print("Error: Failed to convert image: {}\n", .{err});
            return;
        };
        defer img.deinit();
        zikuli.image.savePng(&img, output_file) catch |err| {
            try stderr.print("Error: Failed to save image: {}\n", .{err});
            return;
        };
        try stdout.print("Captured screen {d}x{d} to {s}\n", .{ screen.width(), screen.height(), output_file });
    }
}

fn cmdClick(allocator: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const first_arg = args.next() orelse {
        try stderr.print("Error: click requires coordinates (x y) or --find <pattern>\n", .{});
        return;
    };

    if (std.mem.eql(u8, first_arg, "--find")) {
        // Find pattern and click
        const pattern_file = args.next() orelse {
            try stderr.print("Error: --find requires a pattern file\n", .{});
            return;
        };
        try findAndClick(allocator, pattern_file, stdout, stderr);
    } else {
        // Click at coordinates
        const x = std.fmt.parseInt(i32, first_arg, 10) catch {
            try stderr.print("Error: Invalid x coordinate: {s}\n", .{first_arg});
            return;
        };

        const y_str = args.next() orelse {
            try stderr.print("Error: click requires both x and y coordinates\n", .{});
            return;
        };

        const y = std.fmt.parseInt(i32, y_str, 10) catch {
            try stderr.print("Error: Invalid y coordinate: {s}\n", .{y_str});
            return;
        };

        Mouse.clickAt(x, y, .left) catch |err| {
            try stderr.print("Error: Failed to click: {}\n", .{err});
            return;
        };

        try stdout.print("Clicked at ({d}, {d})\n", .{ x, y });
    }
}

fn cmdDoubleClick(allocator: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    _ = allocator;
    const x_str = args.next() orelse {
        try stderr.print("Error: dclick requires coordinates (x y)\n", .{});
        return;
    };
    const x = std.fmt.parseInt(i32, x_str, 10) catch {
        try stderr.print("Error: Invalid x coordinate: {s}\n", .{x_str});
        return;
    };

    const y_str = args.next() orelse {
        try stderr.print("Error: dclick requires both x and y coordinates\n", .{});
        return;
    };
    const y = std.fmt.parseInt(i32, y_str, 10) catch {
        try stderr.print("Error: Invalid y coordinate: {s}\n", .{y_str});
        return;
    };

    Mouse.smoothMoveTo(x, y) catch |err| {
        try stderr.print("Error: Failed to move mouse: {}\n", .{err});
        return;
    };
    Mouse.doubleClick(.left) catch |err| {
        try stderr.print("Error: Failed to double-click: {}\n", .{err});
        return;
    };

    try stdout.print("Double-clicked at ({d}, {d})\n", .{ x, y });
}

fn cmdRightClick(allocator: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    _ = allocator;
    const x_str = args.next() orelse {
        try stderr.print("Error: rclick requires coordinates (x y)\n", .{});
        return;
    };
    const x = std.fmt.parseInt(i32, x_str, 10) catch {
        try stderr.print("Error: Invalid x coordinate: {s}\n", .{x_str});
        return;
    };

    const y_str = args.next() orelse {
        try stderr.print("Error: rclick requires both x and y coordinates\n", .{});
        return;
    };
    const y = std.fmt.parseInt(i32, y_str, 10) catch {
        try stderr.print("Error: Invalid y coordinate: {s}\n", .{y_str});
        return;
    };

    Mouse.clickAt(x, y, .right) catch |err| {
        try stderr.print("Error: Failed to right-click: {}\n", .{err});
        return;
    };

    try stdout.print("Right-clicked at ({d}, {d})\n", .{ x, y });
}

fn cmdMove(args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    var instant = false;

    // Parse first argument (could be --smooth, --instant, or x coordinate)
    var x_str: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--smooth")) {
            instant = false;
        } else if (std.mem.eql(u8, arg, "--instant")) {
            instant = true;
        } else if (x_str == null) {
            x_str = arg;
        } else {
            // This is y coordinate
            const x = std.fmt.parseInt(i32, x_str.?, 10) catch {
                try stderr.print("Error: Invalid x coordinate: {s}\n", .{x_str.?});
                return;
            };
            const y = std.fmt.parseInt(i32, arg, 10) catch {
                try stderr.print("Error: Invalid y coordinate: {s}\n", .{arg});
                return;
            };

            if (instant) {
                Mouse.moveTo(x, y) catch |err| {
                    try stderr.print("Error: Failed to move mouse: {}\n", .{err});
                    return;
                };
            } else {
                Mouse.smoothMoveTo(x, y) catch |err| {
                    try stderr.print("Error: Failed to move mouse: {}\n", .{err});
                    return;
                };
            }

            try stdout.print("Moved to ({d}, {d})\n", .{ x, y });
            return;
        }
    }

    try stderr.print("Error: move requires coordinates (x y)\n", .{});
}

fn cmdType(args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const text = args.next() orelse {
        try stderr.print("Error: type requires text argument\n", .{});
        return;
    };

    Keyboard.typeText(text) catch |err| {
        try stderr.print("Error: Failed to type text: {}\n", .{err});
        return;
    };

    try stdout.print("Typed: {s}\n", .{text});
}

fn cmdKey(args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const key_spec = args.next() orelse {
        try stderr.print("Error: key requires a key name\n", .{});
        return;
    };

    // Parse key specification (e.g., "ctrl+c", "enter", "f1")
    var modifiers: u32 = 0;
    var key_name: []const u8 = key_spec;

    // Check for modifiers (ctrl+, alt+, shift+, super+)
    var iter = std.mem.splitSequence(u8, key_spec, "+");
    var parts: [5][]const u8 = undefined;
    var part_count: usize = 0;

    while (iter.next()) |part| {
        if (part_count < 5) {
            parts[part_count] = part;
            part_count += 1;
        }
    }

    if (part_count > 1) {
        // Parse modifiers (all but last part)
        for (parts[0 .. part_count - 1]) |mod| {
            if (std.ascii.eqlIgnoreCase(mod, "ctrl")) {
                modifiers |= KeyModifier.CTRL;
            } else if (std.ascii.eqlIgnoreCase(mod, "alt")) {
                modifiers |= KeyModifier.ALT;
            } else if (std.ascii.eqlIgnoreCase(mod, "shift")) {
                modifiers |= KeyModifier.SHIFT;
            } else if (std.ascii.eqlIgnoreCase(mod, "super") or std.ascii.eqlIgnoreCase(mod, "meta") or std.ascii.eqlIgnoreCase(mod, "win")) {
                modifiers |= KeyModifier.SUPER;
            }
        }
        key_name = parts[part_count - 1];
    }

    // Parse key name to keysym
    const keysym = parseKeyName(key_name) orelse {
        try stderr.print("Error: Unknown key: {s}\n", .{key_name});
        return;
    };

    if (modifiers != 0) {
        Keyboard.pressWithModifiers(keysym, modifiers) catch |err| {
            try stderr.print("Error: Failed to press key: {}\n", .{err});
            return;
        };
    } else {
        Keyboard.press(keysym) catch |err| {
            try stderr.print("Error: Failed to press key: {}\n", .{err});
            return;
        };
    }

    try stdout.print("Pressed: {s}\n", .{key_spec});
}

fn cmdOcr(allocator: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    var region_x: ?i32 = null;
    var region_y: ?i32 = null;
    var region_w: ?u32 = null;
    var region_h: ?u32 = null;
    var output_words = false;

    // Parse options
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-x")) {
            region_x = std.fmt.parseInt(i32, args.next() orelse "0", 10) catch 0;
        } else if (std.mem.eql(u8, arg, "-y")) {
            region_y = std.fmt.parseInt(i32, args.next() orelse "0", 10) catch 0;
        } else if (std.mem.eql(u8, arg, "-w")) {
            region_w = std.fmt.parseInt(u32, args.next() orelse "100", 10) catch 100;
        } else if (std.mem.eql(u8, arg, "-h")) {
            region_h = std.fmt.parseInt(u32, args.next() orelse "100", 10) catch 100;
        } else if (std.mem.eql(u8, arg, "--words")) {
            output_words = true;
        }
    }

    // Initialize OCR
    var ocr = OCR.init(allocator) catch |err| {
        try stderr.print("Error: Failed to initialize OCR: {}\n", .{err});
        return;
    };
    defer ocr.deinit();

    // Capture screen/region
    var screen = Screen.primary(allocator) catch |err| {
        try stderr.print("Error: Failed to connect to display: {}\n", .{err});
        return;
    };
    defer screen.deinit();

    var captured = blk: {
        if (region_x != null and region_y != null and region_w != null and region_h != null) {
            const rect = Rectangle.init(region_x.?, region_y.?, region_w.?, region_h.?);
            break :blk screen.captureRegion(rect) catch |err| {
                try stderr.print("Error: Failed to capture region: {}\n", .{err});
                return;
            };
        } else {
            break :blk screen.capture() catch |err| {
                try stderr.print("Error: Failed to capture screen: {}\n", .{err});
                return;
            };
        }
    };
    defer captured.deinit();

    var img = Image.fromCapture(allocator, captured) catch |err| {
        try stderr.print("Error: Failed to convert image: {}\n", .{err});
        return;
    };
    defer img.deinit();

    if (output_words) {
        // Output words with positions
        const words = ocr.readWords(&img) catch |err| {
            try stderr.print("Error: OCR failed: {}\n", .{err});
            return;
        };
        defer {
            for (words) |word| {
                allocator.free(word.text);
            }
            allocator.free(words);
        }

        for (words) |word| {
            try stdout.print("{s}\t{d},{d},{d},{d}\t{d:.1}\n", .{
                word.text,
                word.bounds.x,
                word.bounds.y,
                word.bounds.width,
                word.bounds.height,
                word.confidence,
            });
        }
    } else {
        // Output plain text
        const text = ocr.readText(&img) catch |err| {
            try stderr.print("Error: OCR failed: {}\n", .{err});
            return;
        };
        defer allocator.free(text);

        try stdout.print("{s}", .{text});
    }
}

fn cmdFind(allocator: std.mem.Allocator, args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    var pattern_file: ?[]const u8 = null;
    var similarity: f64 = 0.7;
    var find_all = false;

    // Parse options
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--similarity")) {
            similarity = std.fmt.parseFloat(f64, args.next() orelse "0.7") catch 0.7;
        } else if (std.mem.eql(u8, arg, "--all")) {
            find_all = true;
        } else {
            pattern_file = arg;
        }
    }

    const pattern = pattern_file orelse {
        try stderr.print("Error: find requires a pattern file\n", .{});
        return;
    };

    // Load pattern image
    var pattern_img = zikuli.image.loadPng(allocator, pattern) catch |err| {
        try stderr.print("Error: Failed to load pattern: {}\n", .{err});
        return;
    };
    defer pattern_img.deinit();

    // Capture screen
    var screen = Screen.primary(allocator) catch |err| {
        try stderr.print("Error: Failed to connect to display: {}\n", .{err});
        return;
    };
    defer screen.deinit();

    var captured = screen.capture() catch |err| {
        try stderr.print("Error: Failed to capture screen: {}\n", .{err});
        return;
    };
    defer captured.deinit();

    var screen_img = Image.fromCapture(allocator, captured) catch |err| {
        try stderr.print("Error: Failed to convert image: {}\n", .{err});
        return;
    };
    defer screen_img.deinit();

    // Initialize finder with source image
    var finder = Finder.init(allocator, &screen_img);
    defer finder.deinit();
    finder.setSimilarity(similarity);

    if (find_all) {
        // Find all matches
        const matches = finder.findAll(&pattern_img) catch |err| {
            try stderr.print("Error: Find failed: {}\n", .{err});
            return;
        };
        defer allocator.free(matches);

        if (matches.len == 0) {
            try stdout.print("No matches found\n", .{});
        } else {
            try stdout.print("Found {d} match(es):\n", .{matches.len});
            for (matches) |m| {
                const center = m.center();
                try stdout.print("  ({d}, {d}) score={d:.3}\n", .{ center.x, center.y, m.score });
            }
        }
    } else {
        // Find best match
        const match_opt = finder.find(&pattern_img);
        if (match_opt) |match| {
            const center = match.center();
            try stdout.print("Found at ({d}, {d}) score={d:.3}\n", .{ center.x, center.y, match.score });
        } else {
            try stdout.print("Pattern not found\n", .{});
        }
    }
}

fn cmdDrag(args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const x1_str = args.next() orelse {
        try stderr.print("Error: drag requires 4 coordinates (x1 y1 x2 y2)\n", .{});
        return;
    };
    const y1_str = args.next() orelse {
        try stderr.print("Error: drag requires 4 coordinates (x1 y1 x2 y2)\n", .{});
        return;
    };
    const x2_str = args.next() orelse {
        try stderr.print("Error: drag requires 4 coordinates (x1 y1 x2 y2)\n", .{});
        return;
    };
    const y2_str = args.next() orelse {
        try stderr.print("Error: drag requires 4 coordinates (x1 y1 x2 y2)\n", .{});
        return;
    };

    const x1 = std.fmt.parseInt(i32, x1_str, 10) catch {
        try stderr.print("Error: Invalid x1 coordinate: {s}\n", .{x1_str});
        return;
    };
    const y1 = std.fmt.parseInt(i32, y1_str, 10) catch {
        try stderr.print("Error: Invalid y1 coordinate: {s}\n", .{y1_str});
        return;
    };
    const x2 = std.fmt.parseInt(i32, x2_str, 10) catch {
        try stderr.print("Error: Invalid x2 coordinate: {s}\n", .{x2_str});
        return;
    };
    const y2 = std.fmt.parseInt(i32, y2_str, 10) catch {
        try stderr.print("Error: Invalid y2 coordinate: {s}\n", .{y2_str});
        return;
    };

    Mouse.dragFromTo(x1, y1, x2, y2, .left) catch |err| {
        try stderr.print("Error: Failed to drag: {}\n", .{err});
        return;
    };

    try stdout.print("Dragged from ({d}, {d}) to ({d}, {d})\n", .{ x1, y1, x2, y2 });
}

fn cmdWheel(args: *std.process.ArgIterator, stdout: anytype, stderr: anytype) !void {
    const direction_str = args.next() orelse {
        try stderr.print("Error: wheel requires direction (up or down)\n", .{});
        return;
    };

    const steps_str = args.next() orelse "3";
    const steps = std.fmt.parseInt(u32, steps_str, 10) catch 3;

    if (std.mem.eql(u8, direction_str, "up")) {
        Mouse.wheelUp(steps) catch |err| {
            try stderr.print("Error: Failed to scroll: {}\n", .{err});
            return;
        };
        try stdout.print("Scrolled up {d} steps\n", .{steps});
    } else if (std.mem.eql(u8, direction_str, "down")) {
        Mouse.wheelDown(steps) catch |err| {
            try stderr.print("Error: Failed to scroll: {}\n", .{err});
            return;
        };
        try stdout.print("Scrolled down {d} steps\n", .{steps});
    } else {
        try stderr.print("Error: Invalid direction: {s} (use 'up' or 'down')\n", .{direction_str});
    }
}

fn cmdInfo(allocator: std.mem.Allocator, stdout: anytype) !void {
    try stdout.print("Zikuli {s}\n", .{zikuli.getVersion()});
    try stdout.print("Tesseract OCR: {s}\n\n", .{OCR.version()});

    // Get monitor count
    const count = Screen.getMonitorCount(allocator) catch 1;
    try stdout.print("Monitors: {d}\n", .{count});

    // Display each monitor info
    var i: i32 = 0;
    while (i < @as(i32, @intCast(count))) : (i += 1) {
        var scr = Screen.get(allocator, i) catch continue;
        defer scr.deinit();

        const name = scr.getName();
        if (name.len > 0) {
            try stdout.print("  Monitor {d} ({s}): {d}x{d}+{d}+{d}\n", .{
                i,
                name,
                scr.bounds.width,
                scr.bounds.height,
                scr.bounds.x,
                scr.bounds.y,
            });
        } else {
            try stdout.print("  Monitor {d}: {d}x{d}+{d}+{d}\n", .{
                i,
                scr.bounds.width,
                scr.bounds.height,
                scr.bounds.x,
                scr.bounds.y,
            });
        }
    }

    // Virtual screen info
    var virtual = Screen.virtual(allocator) catch return;
    defer virtual.deinit();
    try stdout.print("\nVirtual screen: {d}x{d}\n", .{ virtual.bounds.width, virtual.bounds.height });

    // Current mouse position
    const pos = Mouse.getPosition() catch return;
    try stdout.print("\nMouse position: ({d}, {d})\n", .{ pos.x, pos.y });
}

fn cmdPos(stdout: anytype) !void {
    const pos = Mouse.getPosition() catch |err| {
        try stdout.print("Error: Failed to get mouse position: {}\n", .{err});
        return;
    };
    try stdout.print("{d} {d}\n", .{ pos.x, pos.y });
}

// ============================================================================
// Helper Functions
// ============================================================================

fn findAndClick(allocator: std.mem.Allocator, pattern_file: []const u8, stdout: anytype, stderr: anytype) !void {
    // Load pattern image
    var pattern_img = zikuli.image.loadPng(allocator, pattern_file) catch |err| {
        try stderr.print("Error: Failed to load pattern: {}\n", .{err});
        return;
    };
    defer pattern_img.deinit();

    // Capture screen
    var screen = Screen.primary(allocator) catch |err| {
        try stderr.print("Error: Failed to connect to display: {}\n", .{err});
        return;
    };
    defer screen.deinit();

    var captured = screen.capture() catch |err| {
        try stderr.print("Error: Failed to capture screen: {}\n", .{err});
        return;
    };
    defer captured.deinit();

    var screen_img = Image.fromCapture(allocator, captured) catch |err| {
        try stderr.print("Error: Failed to convert image: {}\n", .{err});
        return;
    };
    defer screen_img.deinit();

    // Find pattern
    var finder = Finder.init(allocator, &screen_img);
    defer finder.deinit();

    const match_opt = finder.find(&pattern_img);
    if (match_opt) |match| {
        // Click on the center of the match
        const center = match.center();
        Mouse.clickAt(center.x, center.y, .left) catch |err| {
            try stderr.print("Error: Failed to click: {}\n", .{err});
            return;
        };
        try stdout.print("Found and clicked at ({d}, {d}) score={d:.3}\n", .{ center.x, center.y, match.score });
    } else {
        try stderr.print("Error: Pattern not found on screen\n", .{});
    }
}

fn parseKeyName(name: []const u8) ?u32 {
    // Single character
    if (name.len == 1) {
        const c = name[0];
        if (c >= 'a' and c <= 'z') {
            return c; // Lowercase letters are their own keysym
        }
        if (c >= 'A' and c <= 'Z') {
            return c + 32; // Convert to lowercase for keysym
        }
        if (c >= '0' and c <= '9') {
            return c;
        }
    }

    // Named keys (case-insensitive)
    if (std.ascii.eqlIgnoreCase(name, "enter") or std.ascii.eqlIgnoreCase(name, "return")) return KeySym.Return;
    if (std.ascii.eqlIgnoreCase(name, "tab")) return KeySym.Tab;
    if (std.ascii.eqlIgnoreCase(name, "escape") or std.ascii.eqlIgnoreCase(name, "esc")) return KeySym.Escape;
    if (std.ascii.eqlIgnoreCase(name, "space")) return KeySym.space;
    if (std.ascii.eqlIgnoreCase(name, "backspace")) return KeySym.BackSpace;
    if (std.ascii.eqlIgnoreCase(name, "delete") or std.ascii.eqlIgnoreCase(name, "del")) return KeySym.Delete;
    if (std.ascii.eqlIgnoreCase(name, "insert") or std.ascii.eqlIgnoreCase(name, "ins")) return KeySym.Insert;
    if (std.ascii.eqlIgnoreCase(name, "home")) return KeySym.Home;
    if (std.ascii.eqlIgnoreCase(name, "end")) return KeySym.End;
    if (std.ascii.eqlIgnoreCase(name, "pageup") or std.ascii.eqlIgnoreCase(name, "pgup")) return KeySym.Page_Up;
    if (std.ascii.eqlIgnoreCase(name, "pagedown") or std.ascii.eqlIgnoreCase(name, "pgdn")) return KeySym.Page_Down;
    if (std.ascii.eqlIgnoreCase(name, "up")) return KeySym.Up;
    if (std.ascii.eqlIgnoreCase(name, "down")) return KeySym.Down;
    if (std.ascii.eqlIgnoreCase(name, "left")) return KeySym.Left;
    if (std.ascii.eqlIgnoreCase(name, "right")) return KeySym.Right;
    if (std.ascii.eqlIgnoreCase(name, "print") or std.ascii.eqlIgnoreCase(name, "printscreen")) return KeySym.Print;
    if (std.ascii.eqlIgnoreCase(name, "pause")) return KeySym.Pause;
    if (std.ascii.eqlIgnoreCase(name, "capslock")) return KeySym.Caps_Lock;
    if (std.ascii.eqlIgnoreCase(name, "numlock")) return KeySym.Num_Lock;
    if (std.ascii.eqlIgnoreCase(name, "scrolllock")) return KeySym.Scroll_Lock;

    // Function keys
    if (std.ascii.eqlIgnoreCase(name, "f1")) return KeySym.F1;
    if (std.ascii.eqlIgnoreCase(name, "f2")) return KeySym.F2;
    if (std.ascii.eqlIgnoreCase(name, "f3")) return KeySym.F3;
    if (std.ascii.eqlIgnoreCase(name, "f4")) return KeySym.F4;
    if (std.ascii.eqlIgnoreCase(name, "f5")) return KeySym.F5;
    if (std.ascii.eqlIgnoreCase(name, "f6")) return KeySym.F6;
    if (std.ascii.eqlIgnoreCase(name, "f7")) return KeySym.F7;
    if (std.ascii.eqlIgnoreCase(name, "f8")) return KeySym.F8;
    if (std.ascii.eqlIgnoreCase(name, "f9")) return KeySym.F9;
    if (std.ascii.eqlIgnoreCase(name, "f10")) return KeySym.F10;
    if (std.ascii.eqlIgnoreCase(name, "f11")) return KeySym.F11;
    if (std.ascii.eqlIgnoreCase(name, "f12")) return KeySym.F12;

    return null;
}

test "main module loads" {
    // Just verify the module can be imported
    try std.testing.expectEqualStrings("0.1.0", zikuli.getVersion());
}

test "parseKeyName: basic keys" {
    try std.testing.expectEqual(@as(?u32, KeySym.Return), parseKeyName("enter"));
    try std.testing.expectEqual(@as(?u32, KeySym.Return), parseKeyName("Enter"));
    try std.testing.expectEqual(@as(?u32, KeySym.Tab), parseKeyName("tab"));
    try std.testing.expectEqual(@as(?u32, KeySym.Escape), parseKeyName("esc"));
    try std.testing.expectEqual(@as(?u32, KeySym.F1), parseKeyName("f1"));
    try std.testing.expectEqual(@as(?u32, KeySym.F12), parseKeyName("F12"));
}

test "parseKeyName: single characters" {
    try std.testing.expectEqual(@as(?u32, 'a'), parseKeyName("a"));
    try std.testing.expectEqual(@as(?u32, 'a'), parseKeyName("A")); // Uppercase converts to lowercase
    try std.testing.expectEqual(@as(?u32, '5'), parseKeyName("5"));
}
