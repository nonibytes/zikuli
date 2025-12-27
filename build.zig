const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.

    // This creates a module, which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Zig modules are the preferred way of making Zig code available to consumers.
    // addModule defines a module that we intend to make available for importing
    // to our consumers. We must give it a name because a Zig package can expose
    // multiple modules and consumers will need to be able to specify which
    // module they want to access.
    const mod = b.addModule("zikuli", .{
        // The root source file is the "entry point" of this module. Users of
        // this module will only be able to access public declarations contained
        // in this file, which means that if you have declarations that you
        // intend to expose to consumers that were defined in other files part
        // of this module, you will have to make sure to re-export them from
        // the root file.
        .root_source_file = b.path("src/root.zig"),
        // Later on we'll use this module as the root module of a test executable
        // which requires us to specify a target.
        .target = target,
        // Link X11/XCB libraries for screen capture
        .link_libc = true,
    });

    // Link X11/XCB system libraries
    mod.linkSystemLibrary("xcb", .{});
    mod.linkSystemLibrary("xcb-shm", .{});
    mod.linkSystemLibrary("xcb-image", .{});

    // Link Xlib and XTest for synthetic input (Phase 5)
    mod.linkSystemLibrary("X11", .{});
    mod.linkSystemLibrary("Xtst", .{});

    // Link image handling libraries
    mod.linkSystemLibrary("png", .{});

    // Link OpenCV for template matching
    mod.linkSystemLibrary("opencv4", .{});

    // Add include path for our OpenCV wrapper header
    mod.addIncludePath(b.path("src/opencv"));

    // Compile the OpenCV C++ wrapper
    mod.addCSourceFile(.{
        .file = b.path("src/opencv/opencv_wrapper.cpp"),
        .flags = &.{ "-std=c++11" },
    });

    // Link C++ runtime
    mod.linkSystemLibrary("stdc++", .{});

    // Link Tesseract OCR and Leptonica for text recognition (Phase 8)
    mod.linkSystemLibrary("tesseract", .{});
    mod.linkSystemLibrary("lept", .{});

    // Here we define an executable. An executable needs to have a root module
    // which needs to expose a `main` function. While we could add a main function
    // to the module defined above, it's sometimes preferable to split business
    // logic and the CLI into two separate modules.
    //
    // If your goal is to create a Zig library for others to use, consider if
    // it might benefit from also exposing a CLI tool. A parser library for a
    // data serialization format could also bundle a CLI syntax checker, for example.
    //
    // If instead your goal is to create an executable, consider if users might
    // be interested in also being able to embed the core functionality of your
    // program in their own executable in order to avoid the overhead involved in
    // subprocessing your CLI tool.
    //
    // If neither case applies to you, feel free to delete the declaration you
    // don't need and to put everything under a single module.
    const exe = b.addExecutable(.{
        .name = "zikuli",
        .root_module = b.createModule(.{
            // b.createModule defines a new module just like b.addModule but,
            // unlike b.addModule, it does not expose the module to consumers of
            // this package, which is why in this case we don't have to give it a name.
            .root_source_file = b.path("src/main.zig"),
            // Target and optimization levels must be explicitly wired in when
            // defining an executable or library (in the root module), and you
            // can also hardcode a specific target for an executable or library
            // definition if desireable (e.g. firmware for embedded devices).
            .target = target,
            .optimize = optimize,
            // List of modules available for import in source files part of the
            // root module.
            .imports = &.{
                // Here "zikuli" is the name you will use in your source code to
                // import this module (e.g. `@import("zikuli")`). The name is
                // repeated because you are allowed to rename your imports, which
                // can be extremely useful in case of collisions (which can happen
                // importing modules from different packages).
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.

    // ========================================================================
    // Integration Tests (verification tests with actual X11)
    // ========================================================================

    // Test capture executable for verifying X11 screen capture
    const test_capture = b.addExecutable(.{
        .name = "test_capture",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_capture.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(test_capture);

    const run_test_capture = b.addRunArtifact(test_capture);
    const test_capture_step = b.step("test-capture", "Run X11 capture verification test");
    test_capture_step.dependOn(&run_test_capture.step);

    // Test finder executable for verifying OpenCV template matching
    const test_finder = b.addExecutable(.{
        .name = "test_finder",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_finder.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(test_finder);

    const run_test_finder = b.addRunArtifact(test_finder);
    const test_finder_step = b.step("test-finder", "Run OpenCV template matching verification test");
    test_finder_step.dependOn(&run_test_finder.step);

    // Test mouse executable for verifying XTest mouse control (Phase 5)
    const test_mouse = b.addExecutable(.{
        .name = "test_mouse",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_mouse.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(test_mouse);

    const run_test_mouse = b.addRunArtifact(test_mouse);
    const test_mouse_step = b.step("test-mouse", "Run XTest mouse control verification test");
    test_mouse_step.dependOn(&run_test_mouse.step);

    // Test keyboard executable for verifying XTest keyboard control (Phase 6)
    const test_keyboard = b.addExecutable(.{
        .name = "test_keyboard",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_keyboard.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(test_keyboard);

    const run_test_keyboard = b.addRunArtifact(test_keyboard);
    const test_keyboard_step = b.step("test-keyboard", "Run XTest keyboard control verification test");
    test_keyboard_step.dependOn(&run_test_keyboard.step);

    // Test region operations executable for verifying integrated find/click/wait (Phase 7)
    const test_region_ops = b.addExecutable(.{
        .name = "test_region_ops",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_region_ops.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(test_region_ops);

    const run_test_region_ops = b.addRunArtifact(test_region_ops);
    const test_region_ops_step = b.step("test-region-ops", "Run Region operations integration test (Phase 7)");
    test_region_ops_step.dependOn(&run_test_region_ops.step);

    // Test OCR executable for verifying Tesseract integration (Phase 8)
    const test_ocr = b.addExecutable(.{
        .name = "test_ocr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/test_ocr.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(test_ocr);

    const run_test_ocr = b.addRunArtifact(test_ocr);
    const test_ocr_step = b.step("test-ocr", "Run Tesseract OCR integration test (Phase 8)");
    test_ocr_step.dependOn(&run_test_ocr.step);

    // ========================================================================
    // Example Executables (Phase 9)
    // ========================================================================

    // Basic automation example
    const example_basic = b.addExecutable(.{
        .name = "example_basic",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/basic_automation.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(example_basic);

    const run_example_basic = b.addRunArtifact(example_basic);
    const example_basic_step = b.step("run-example-basic", "Run basic automation example");
    example_basic_step.dependOn(&run_example_basic.step);

    // Find and click example
    const example_find = b.addExecutable(.{
        .name = "example_find",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/find_and_click.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(example_find);

    const run_example_find = b.addRunArtifact(example_find);
    const example_find_step = b.step("run-example-find", "Run find and click example");
    example_find_step.dependOn(&run_example_find.step);

    // Type text example
    const example_type = b.addExecutable(.{
        .name = "example_type",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/type_text.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(example_type);

    const run_example_type = b.addRunArtifact(example_type);
    const example_type_step = b.step("run-example-type", "Run type text example");
    example_type_step.dependOn(&run_example_type.step);

    // OCR example
    const example_ocr = b.addExecutable(.{
        .name = "example_ocr",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/ocr_text.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zikuli", .module = mod },
            },
        }),
    });
    b.installArtifact(example_ocr);

    const run_example_ocr = b.addRunArtifact(example_ocr);
    const example_ocr_step = b.step("run-example-ocr", "Run OCR text recognition example");
    example_ocr_step.dependOn(&run_example_ocr.step);
}
