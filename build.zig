const std = @import("std");
const z_wav = @import("zigggwavvv");

pub const Wave = @import("./src/wave.zig");
pub const Composer = @import("./src/composer.zig");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const zigggwavvv = b.dependency("zigggwavvv", .{});
    const zaudio = b.dependency("zaudio", .{});

    // Library module declaration
    const lib_mod = b.addModule("lightmix", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zigggwavvv", .module = zigggwavvv.module("zigggwavvv") },
            .{ .name = "zaudio", .module = zaudio.module("root") },
        },
    });

    // miniaudio linking
    lib_mod.linkLibrary(zaudio.artifact("miniaudio"));

    // # macOS
    // apple-sdk framework linking is needed if your machine runs macOS.
    // This needs SDKROOT environment variable.
    // Your SDKROOT should be a string as "/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk" (If you don't set SDKROOT, lightmix uses "xcrun --show-sdk-path" command to get SDKROOT).
    // You can use pkgs.apple-sdk on nixpkgs with "pkgs.mkShell". You should have SDKROOT environment variable by pkgs.apple-sdk's hook when you use "pkgs.mkShell".
    //
    // I must write below programs, because "miniaudio" linking needs macOS SDK on macOS.
    if (target.result.os.tag == .macos) {
        const maybe_sdkroot: ?[]const u8 = b.graph.environ_map.get("SDKROOT") orelse inner: {
            // Only run xcrun if the host operating system is macOS
            if (b.graph.host.result.os.tag == .macos) {
                const argv = &.{ "xcrun", "--show-sdk-path" };
                const result = b.run(argv); // The stdout of "xcrun --show-sdk-path"
                break :inner result;
            }
            break :inner null;
        };
        if (maybe_sdkroot) |sdkroot_envvar| {
            const trimmed_sdkroot = std.mem.trim(u8, sdkroot_envvar, " \t\r\n");
            const sdkroot: []const u8 = try std.mem.concat(b.allocator, u8, &.{ trimmed_sdkroot, "/System/Library/Frameworks" });
            lib_mod.addFrameworkPath(.{ .cwd_relative = sdkroot });

            // This part adds library paths to lib_mod variable.
            const sdkroot_libpath: []const u8 = try std.mem.concat(b.allocator, u8, &.{ trimmed_sdkroot, "/usr/lib" });
            lib_mod.addLibraryPath(.{ .cwd_relative = sdkroot_libpath });
        }
    }

    // Library installation
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lightmix",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    // Library unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Integration tests
    // Wave
    const wave_integration_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/wave.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lib_mod },
            },
        }),
    });
    const run_wave_integration_tests = b.addRunArtifact(wave_integration_test);
    test_step.dependOn(&run_wave_integration_tests.step);

    // Composer
    const composer_integration_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/composer.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lib_mod },
            },
        }),
    });
    const run_composer_integration_tests = b.addRunArtifact(composer_integration_test);
    test_step.dependOn(&run_composer_integration_tests.step);

    // Examples
    try example_verifications(b, target, optimize, lib_mod, test_step);

    // Docs
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "share/lightmix/docs",
    });
    docs_step.dependOn(&docs_install.step);
}

/// Examples' verifications
fn example_verifications(b: *std.Build, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, lightmix_mod: *std.Build.Module, test_step: *std.Build.Step) !void {
    const example_files = &[_][]const u8{
        "examples/01-getting-started/hello-wave/src/main.zig",
        "examples/01-getting-started/using-filters/src/main.zig",
        "examples/02-wave-basics/noise/src/main.zig",
        "examples/02-wave-basics/sawtooth-wave/src/main.zig",
        "examples/02-wave-basics/sine-wave/src/main.zig",
        "examples/02-wave-basics/square-wave/src/main.zig",
        "examples/02-wave-basics/triangle-wave/src/main.zig",
        "examples/03-wave-operations/filtering/src/main.zig",
        "examples/03-wave-operations/frequency-changes/src/main.zig",
        "examples/03-wave-operations/mixing-waves/src/main.zig",
        "examples/04-composer/overlapping-sounds/src/main.zig",
        "examples/04-composer/simple-sequence/src/main.zig",
        "examples/05-practical-examples/drum/src/main.zig",
        "examples/05-practical-examples/guitar/src/main.zig",
        "examples/06-advanced/runtime-play/src/main.zig",
    };

    for (example_files, 0..) |ex_path, i| {
        const name = try std.fmt.allocPrint(b.allocator, "example_{d}", .{i});
        const example_mod = b.createModule(.{
            .root_source_file = b.path(ex_path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lightmix_mod },
            },
        });
        const example_exe = b.addExecutable(.{
            .name = name,
            .root_module = example_mod,
        });
        test_step.dependOn(&example_exe.step);
    }

    const bt_gen_mod = b.createModule(.{
        .root_source_file = b.path("examples/06-advanced/build-time-generation/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix_mod },
        },
    });
    const bt_gen_wave = try addWave(b, bt_gen_mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
            .name = "build-time-generation.wav",
        } },
    });
    test_step.dependOn(bt_gen_wave.step);

    const bt_play_mod = b.createModule(.{
        .root_source_file = b.path("examples/06-advanced/build-time-play/src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix_mod },
        },
    });
    const bt_play_wave = try addWave(b, bt_play_mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
            .name = "build-time-play.wav",
        } },
    });
    test_step.dependOn(bt_play_wave.step);

    // Integration test for use_fact chunk option in addWave (#221)
    const bt_fact_wave = try addWave(b, bt_gen_mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
            .use_fact = true,
            .name = "test-use-fact.wav",
        } },
    });
    const test_fact_exe = b.addExecutable(.{
        .name = "test_build_fact",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/build_fact.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lightmix_mod },
            },
        }),
    });
    const run_test_fact = b.addRunArtifact(test_fact_exe);
    run_test_fact.addFileArg(bt_fact_wave.output_file);
    test_step.dependOn(&run_test_fact.step);

    // Integration test for use_peak and peak_timestamp chunk options in addWave (#222)
    const bt_peak_wave = try addWave(b, bt_gen_mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
            .use_peak = true,
            .peak_timestamp = 1700000000,
            .name = "test-use-peak.wav",
        } },
    });
    const test_peak_exe = b.addExecutable(.{
        .name = "test_build_peak",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/build_peak.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lightmix_mod },
            },
        }),
    });
    const run_test_peak = b.addRunArtifact(test_peak_exe);
    run_test_peak.addFileArg(bt_peak_wave.output_file);
    test_step.dependOn(&run_test_peak.step);

    // Integration test for currentTimestamp used as peak_timestamp in addWave (#366)
    const bt_peak_now_timestamp = currentTimestamp(b);
    const bt_peak_now_wave = try addWave(b, bt_gen_mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
            .use_peak = true,
            .peak_timestamp = bt_peak_now_timestamp,
            .name = "test-use-peak-now.wav",
        } },
    });
    const test_peak_now_exe = b.addExecutable(.{
        .name = "test_build_peak_now",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/build_peak_now.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_test_peak_now = b.addRunArtifact(test_peak_now_exe);
    run_test_peak_now.addFileArg(bt_peak_now_wave.output_file);
    run_test_peak_now.addArg(b.fmt("{d}", .{bt_peak_now_timestamp}));
    test_step.dependOn(&run_test_peak_now.step);

    // Integration test for ieee_float format code in addWave (#230)
    const bt_float_wave = try addWave(b, bt_gen_mod, .{
        .optimize = optimize,
        .format = .{ .wav = .{
            .bits = 32,
            .format_code = .ieee_float,
            .name = "test-ieee-float.wav",
        } },
    });
    const test_float_exe = b.addExecutable(.{
        .name = "test_build_ieee_float",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/build_ieee_float.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "lightmix", .module = lightmix_mod },
            },
        }),
    });
    const run_test_float = b.addRunArtifact(test_float_exe);
    run_test_float.addFileArg(bt_float_wave.output_file);
    test_step.dependOn(&run_test_float.step);

    // TODO: l.addPlay function cannot be tested via `zig build test` command. I (@haruki7049) cannot write it.
}

/// Creates a build step that generates a WAV file at compile time.
///
/// This function enables compile-time audio generation by calling a user-defined
/// function that returns a Wave instance, then writing it to a WAV file during
/// the build process.
///
/// ## Parameters
/// - `b`: The build context
/// - `mod`: The module containing the wave generation function
/// - `options`: Configuration options for wave generation
///
/// ## Returns
/// A pointer to a value typed CompileWave
///
/// ## Errors
/// Returns errors from:
/// - File system operations (creating cache directory, writing files)
/// - Memory allocation failures
/// - The user-provided wave generation function (if it returns an error)
///
/// ## Usage
/// ```zig
/// const std = @import("std");
/// const l = @import("lightmix");
///
/// pub fn build(b: *std.Build) !void {
///     const target = b.standardTargetOptions(.{});
///     const optimize = b.standardOptimizeOption(.{});
///
///     // Dependencies
///     const lightmix = b.dependency("lightmix", .{});
///
///     // Module
///     const mod = b.createModule(.{
///         .root_source_file = b.path("src/main.zig"),
///         .target = target,
///         .optimize = optimize,
///         .imports = &.{
///             .{ .name = "lightmix", .module = lightmix.module("lightmix") },
///         },
///     });
///
///     // Install Wave file into `zig-out` as `result.wav` (default Wave name)
///     const wave = try l.addWave(b, mod, .{
///         .func_name = "gen",
///         .format = .{ .wav = .{ .bits = 16, .format_code = .pcm } },
///     });
///     b.getInstallStep().dependOn(wave.step);
/// }
/// ```
///
/// The user module must export a function matching the signature specified in
/// `options.func_name` (default: "gen") that returns `!lightmix.Wave(T)`, and receives an argument `std.process.Init`.
pub fn addWave(
    b: *std.Build,
    mod: *std.Build.Module,
    options: CreateWaveOptions,
) anyerror!*CompileWave {
    return switch (options.format) {
        .wav => Generator.Wav.gen(b, mod, options),
    };
}

/// Returns a timestamp in seconds since the Unix epoch, suitable for `WavOptions.peak_timestamp`.
///
/// If the `SOURCE_DATE_EPOCH` environment variable is set to a valid unsigned integer, that value
/// is returned so that builds stay reproducible. Otherwise the current wall-clock time is used.
/// Values outside the `u32` range are saturated instead of trapping.
///
/// Note: a wall-clock value changes on every `zig build`, so the generated wave is not cached
/// across invocations. Leave `peak_timestamp` at its default (`0`) for a reproducible output.
///
/// ## Usage
/// ```zig
/// const wave = try l.addWave(b, mod, .{
///     .format = .{ .wav = .{
///         .bits = 16,
///         .format_code = .pcm,
///         .use_peak = true,
///         .peak_timestamp = l.currentTimestamp(b),
///     } },
/// });
/// ```
pub fn currentTimestamp(b: *std.Build) u32 {
    if (b.graph.environ_map.get("SOURCE_DATE_EPOCH")) |value| {
        if (std.fmt.parseInt(u32, value, 10)) |seconds| return seconds else |_| {}
    }

    const seconds = std.Io.Clock.real.now(b.graph.io).toSeconds();
    return std.math.lossyCast(u32, seconds);
}

const Generator = struct {
    const ExeCacheEntry = struct {
        b: *std.Build,
        mod: *std.Build.Module,
        func_name: []const u8,
        optimize: std.builtin.OptimizeMode,
        exe: *std.Build.Step.Compile,
    };

    var cache_list: std.ArrayListUnmanaged(ExeCacheEntry) = .empty;

    fn getOrCreateExe(
        b: *std.Build,
        mod: *std.Build.Module,
        func_name: []const u8,
        optimize: std.builtin.OptimizeMode,
    ) !*std.Build.Step.Compile {
        for (cache_list.items) |entry| {
            if (entry.b == b and entry.mod == mod and std.mem.eql(u8, entry.func_name, func_name) and entry.optimize == optimize) {
                return entry.exe;
            }
        }

        // Generate temporary Zig code that parses command-line arguments dynamically
        const gen_source = try std.fmt.allocPrint(b.allocator,
            \\const std = @import("std");
            \\const user_module = @import("user_module");
            \\
            \\pub fn main(init: std.process.Init) !void {{
            \\    const allocator: std.mem.Allocator = init.arena.allocator();
            \\    const io: std.Io = init.io;
            \\
            \\    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
            \\    defer args_it.deinit();
            \\    _ = args_it.skip();
            \\    const output_path = args_it.next() orelse return error.MissingOutputFileArg;
            \\    const bits_str = args_it.next() orelse return error.MissingBitsArg;
            \\    const format_str = args_it.next() orelse return error.MissingFormatCodeArg;
            \\    const use_fact_str = args_it.next() orelse return error.MissingUseFactArg;
            \\    const use_peak_str = args_it.next() orelse return error.MissingUsePeakArg;
            \\    const peak_timestamp_str = args_it.next() orelse return error.MissingPeakTimestampArg;
            \\
            \\    const bits = try std.fmt.parseInt(u16, bits_str, 10);
            \\    const use_fact = std.mem.eql(u8, use_fact_str, "true");
            \\    const use_peak = std.mem.eql(u8, use_peak_str, "true");
            \\    const peak_timestamp = try std.fmt.parseInt(u32, peak_timestamp_str, 10);
            \\
            \\    const wave = try user_module.{s}(init);
            \\    defer wave.deinit();
            \\
            \\    const file = try std.Io.Dir.cwd().createFile(io, output_path, .{{}});
            \\    defer file.close(io);
            \\    var buf: [64 * 1024]u8 = undefined;
            \\    var writer = file.writer(io, &buf);
            \\
            \\    if (std.mem.eql(u8, format_str, "pcm")) {{
            \\        try wave.write(.wav, &writer.interface, .{{
            \\            .format_code = .pcm,
            \\            .bits = bits,
            \\            .use_fact = use_fact,
            \\            .use_peak = use_peak,
            \\            .peak_timestamp = peak_timestamp,
            \\        }});
            \\    }} else if (std.mem.eql(u8, format_str, "ieee_float")) {{
            \\        try wave.write(.wav, &writer.interface, .{{
            \\            .format_code = .ieee_float,
            \\            .bits = bits,
            \\            .use_fact = use_fact,
            \\            .use_peak = use_peak,
            \\            .peak_timestamp = peak_timestamp,
            \\        }});
            \\    }} else {{
            \\        return error.InvalidFormatCode;
            \\    }}
            \\
            \\    try writer.interface.flush();
            \\}}
        , .{
            func_name,
        });

        const write_files = b.addWriteFiles();
        const exe_name = try std.fmt.allocPrint(b.allocator, "wave_generator_{s}", .{func_name});
        const gen_file = write_files.add("wave_gen.zig", gen_source);

        const host_user_mod = b.createModule(.{
            .root_source_file = mod.root_source_file,
            .target = b.graph.host,
            .optimize = optimize,
        });
        var import_it = mod.import_table.iterator();
        while (import_it.next()) |entry| {
            host_user_mod.addImport(entry.key_ptr.*, entry.value_ptr.*);
        }

        const gen_exe = b.addExecutable(.{
            .name = exe_name,
            .root_module = b.createModule(.{
                .root_source_file = gen_file,
                .target = b.graph.host,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "user_module", .module = host_user_mod },
                },
            }),
        });

        try cache_list.append(b.allocator, .{
            .b = b,
            .mod = mod,
            .func_name = func_name,
            .optimize = optimize,
            .exe = gen_exe,
        });

        return gen_exe;
    }

    const Wav = struct {
        fn gen(
            b: *std.Build,
            mod: *std.Build.Module,
            options: CreateWaveOptions,
        ) anyerror!*CompileWave {
            const gen_exe = try getOrCreateExe(b, mod, options.func_name, options.optimize);

            // Run the generator during build with output path, bits, and format code arguments
            const run_gen = b.addRunArtifact(gen_exe);
            const output_wave_file = run_gen.addOutputFileArg(options.format.wav.name);
            run_gen.addArg(b.fmt("{d}", .{options.format.wav.bits}));
            run_gen.addArg(@tagName(options.format.wav.format_code));
            run_gen.addArg(if (options.format.wav.use_fact) "true" else "false");
            run_gen.addArg(if (options.format.wav.use_peak) "true" else "false");
            run_gen.addArg(b.fmt("{d}", .{options.format.wav.peak_timestamp}));

            // Install the generated wave file
            const install_wave = b.addInstallFileWithDir(
                output_wave_file,
                options.path,
                options.format.wav.name,
            );

            const result = try b.allocator.create(CompileWave);
            result.* = CompileWave{
                .step = &install_wave.step,
                .root_module = mod,
                .name = options.format.wav.name,
                .create_wave_options = options,
                .output_file = output_wave_file,
            };
            return result;
        }
    };
};

/// A return type for addWave function.
pub const CompileWave = struct {
    step: *std.Build.Step,
    root_module: *std.Build.Module,
    name: []const u8,
    create_wave_options: CreateWaveOptions,
    output_file: std.Build.LazyPath,
};

/// Options for configuring compile-time wave generation.
///
/// These options control how the wave generation function is called and
/// where the resulting WAV file is installed.
pub const CreateWaveOptions = struct {
    /// Name of the function in the module that generates the Wave.
    /// The function must have signature: `pub fn name(init: std.process.Init) !lightmix.Wave(T)`
    /// where T is typically f64, f80, or f128.
    func_name: []const u8 = "gen",

    /// Destination path relative to the install prefix where the WAV file will be installed.
    /// Defaults to the "share" directory.
    path: std.Build.InstallDir = .{ .custom = "share" },

    /// Optimization mode for the wave generator executable.
    /// Defaults to `.ReleaseFast` for high performance wave synthesis.
    optimize: std.builtin.OptimizeMode = .ReleaseFast,

    /// Output format and codec-specific options for the wave file to generate.
    format: FormatOptions,
};

/// Tagged union that selects the output format and carries its format-specific options.
pub const FormatOptions = union(enum) {
    wav: WavOptions,
};

/// Options for configuring a WAV file's output properties.
///
/// This struct specifies the output filename, bit depth, and audio format
/// for the generated WAV file.
pub const WavOptions = struct {
    /// The output filename for the wave file (e.g., "result.wav", "audio.wav").
    name: []const u8 = "result.wav",

    /// The bit depth for the wave file (e.g., 16, 24, or 32 bits per sample).
    bits: u16,

    /// Audio encoding format such as .pcm (PCM integer) or .ieee_float (floating-point).
    format_code: z_wav.FormatCode,

    /// Whether to include a 'fact' chunk in the WAV header (default: false).
    use_fact: bool = false,

    /// Whether to include a 'PEAK' chunk in the WAV header (default: false).
    use_peak: bool = false,

    /// Optional timestamp for the 'PEAK' chunk in seconds since Unix epoch (default: 0).
    peak_timestamp: u32 = 0,
};

/// A helper function to install Wave file from a pointer of a value typed CompileWave.
///
/// This function does as the following:
///
/// ```
/// b.getInstallStep().dependOn(wave.step);
/// ```
///
/// ## Usage
/// ```
/// // Install Wave file into `zig-out` as `result.wav` (default Wave name)
/// const wave = try l.addWave(b, mod, .{
///     .func_name = "gen",
///     .format = .{ .wav = .{ .bits = 16, .format_code = .pcm } },
/// });
/// l.installWave(b, wave);
/// ```
pub fn installWave(b: *std.Build, wave: *CompileWave) void {
    b.getInstallStep().dependOn(wave.step);
}

/// Create a run step that plays the wave generated by CompileWave.
///
/// This function creates a build step that:
/// 1. Generates an executable that calls the wave generation function
/// 2. Calls the play() method on the resulting Wave
/// 3. Returns a Run step that can be added as a dependency
///
/// ## Parameters
/// - `b`: Build context
/// - `wave`: Pointer to CompileWave containing the wave generation function info
/// - `options`: Options for creating the play executable
///
/// ## Returns
/// A Run step that executes the play functionality
///
/// ## Usage
/// ```zig
/// const wave = try l.addWave(b, mod, .{
///     .format = .{ .wav = .{ .bits = 16, .format_code = .pcm } },
/// });
/// const play = try l.addPlay(b, wave, .{});
/// l.installPlay(b, play);
/// ```
pub fn addPlay(
    b: *std.Build,
    wave: *CompileWave,
    options: PlayOptions,
) anyerror!*std.Build.Step.Run {
    // Generate temporary Zig code that calls the user's function and plays it
    const play_source = try std.fmt.allocPrint(b.allocator,
        \\const std = @import("std");
        \\const user_module = @import("user_module");
        \\
        \\pub fn main(init: std.process.Init) !void {{
        \\    const wave = try user_module.{s}(init);
        \\    defer wave.deinit();
        \\    try wave.play();
        \\}}
        \\
    , .{wave.create_wave_options.func_name});

    // Create a write files step to generate the temporary source
    const write_files = b.addWriteFiles();
    const play_source_file = write_files.add("play_wave.zig", play_source);

    const host_user_mod = b.createModule(.{
        .root_source_file = wave.root_module.root_source_file,
        .target = b.graph.host,
        .optimize = options.optimize,
    });
    var import_it = wave.root_module.import_table.iterator();
    while (import_it.next()) |entry| {
        host_user_mod.addImport(entry.key_ptr.*, entry.value_ptr.*);
    }

    // Create executable that plays the wave
    const play_exe = b.addExecutable(.{
        .name = options.exe_name,
        .root_module = b.createModule(.{
            .root_source_file = play_source_file,
            .target = b.graph.host,
            .optimize = options.optimize,
            .imports = &.{
                .{ .name = "user_module", .module = host_user_mod },
            },
        }),
    });

    // Create and return a run step
    const run_play = b.addRunArtifact(play_exe);

    return run_play;
}

/// A helper function to play Wave at build time from a Run step.
///
/// This function does as the following:
///
/// ```
/// b.getInstallStep().dependOn(&play.step);
/// ```
///
/// ## Usage
/// ```zig
/// // Play Wave at build time
/// const wave = try l.addWave(b, mod, .{
///     .func_name = "gen",
///     .format = .{ .wav = .{ .bits = 16, .format_code = .pcm } },
/// });
/// const play = try l.addPlay(b, wave, .{});
/// l.installPlay(b, play);
/// ```
pub fn installPlay(b: *std.Build, play: *std.Build.Step.Run) void {
    b.getInstallStep().dependOn(&play.step);
}

/// Options for creating a play executable
pub const PlayOptions = struct {
    /// Name of the generated executable
    exe_name: []const u8 = "play_wave",

    /// Optimization mode for the executable
    optimize: std.builtin.OptimizeMode = .Debug,
};
