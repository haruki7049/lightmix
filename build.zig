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
        const sdkroot_envvar: []const u8 = b.graph.env_map.get("SDKROOT") orelse inner: {
            // These processes need "xcrun" command
            const argv = &.{ "xcrun", "--show-sdk-path" };
            const result = b.run(argv); // The stdout of "xcrun --show-sdk-path"

            break :inner result;
        };
        const sdkroot: []const u8 = try std.mem.concat(b.allocator, u8, &.{ sdkroot_envvar, "/System/Library/Frameworks" });
        lib_mod.addFrameworkPath(.{ .cwd_relative = sdkroot });
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

    // Docs
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "share/lightmix/docs",
    });
    docs_step.dependOn(&docs_install.step);
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
///         .wave = .{ .bits = 16, .format_code = .pcm },
///     });
///     b.getInstallStep().dependOn(wave.step);
/// }
/// ```
///
/// The user module must export a function matching the signature specified in
/// `options.func_name` (default: "gen") that returns `!lightmix.Wave(T)`.
pub fn addWave(
    b: *std.Build,
    mod: *std.Build.Module,
    options: CreateWaveOptions,
) anyerror!*CompileWave {
    // Create .zig-cache/lightmix directory
    b.cache_root.handle.access("lightmix", .{}) catch {
        try b.cache_root.handle.makeDir("lightmix");
    };

    // Create a wave file in .zig-cache/lightmix
    const tmp_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{
        try b.build_root.handle.realpathAlloc(b.allocator, "."),
        ".zig-cache",
        "lightmix",
        options.wave.name,
    });
    // Generate temporary Zig code that calls the user's function
    const gen_source = try std.fmt.allocPrint(b.allocator,
        \\const std = @import("std");
        \\const user_module = @import("user_module");
        \\const allocator = std.heap.page_allocator;
        \\
        \\pub fn main() !void {{
        \\    const wave = try user_module.{s}();
        \\    defer wave.deinit();
        \\
        \\    const file = try std.fs.cwd().createFile("{s}", .{{}});
        \\    defer file.close();
        \\    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
        \\    defer allocator.free(buf);
        \\    var writer = file.writer(buf);
        \\
        \\    try wave.write(&writer.interface, .{{
        \\        .allocator = allocator,
        \\        .format_code = .{s},
        \\        .bits = {d},
        \\    }});
        \\
        \\    try writer.interface.flush();
        \\}}
    , .{
        options.func_name,
        tmp_path,
        @tagName(options.wave.format_code),
        options.wave.bits,
    });

    // Create a write files step to generate the temporary source
    const write_files = b.addWriteFiles();
    const gen_file = write_files.add("wave_gen.zig", gen_source);

    // Create executable that generates the wave
    const gen_exe = b.addExecutable(.{
        .name = "wave_generator",
        .root_module = b.createModule(.{
            .root_source_file = gen_file,
            .target = b.graph.host,
            .optimize = .Debug,
            .imports = &.{
                .{ .name = "user_module", .module = mod },
            },
        }),
    });

    // Run the generator during build
    const run_gen = b.addRunArtifact(gen_exe);

    const src_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ ".zig-cache", "lightmix", options.wave.name });
    // Install the generated wave file
    const install_wave = b.addInstallFileWithDir(
        b.path(src_path),
        options.path,
        options.wave.name,
    );
    install_wave.step.dependOn(&run_gen.step);

    var result = CompileWave{
        .step = &install_wave.step,
        .root_module = mod,
        .name = options.wave.name,
    };
    return &result;
}

/// A return type for addWave function.
pub const CompileWave = struct {
    step: *std.Build.Step,
    root_module: *std.Build.Module,
    name: []const u8,
};

/// Options for configuring compile-time wave generation.
///
/// These options control how the wave generation function is called and
/// where the resulting WAV file is installed.
pub const CreateWaveOptions = struct {
    /// Name of the function in the module that generates the Wave.
    /// The function must have signature: `pub fn name() !lightmix.Wave(T)`
    /// where T is typically f64, f80, or f128.
    func_name: []const u8 = "gen",

    /// Destination path relative to the install prefix where the WAV file will be installed.
    /// Defaults to the "share" directory.
    path: std.Build.InstallDir = .{ .custom = "share" },

    /// Configuration for the wave file output (filename, bit depth, and format).
    wave: WavefileOptions,
};

/// Options for configuring a wave file's output properties.
///
/// This struct specifies the output filename, bit depth, and audio format
/// for the generated WAV file.
pub const WavefileOptions = struct {
    /// The output filename for the wave file (e.g., "result.wav", "audio.wav").
    name: []const u8 = "result.wav",

    /// The bit depth for the wave file (e.g., 16, 24, or 32 bits per sample).
    bits: u16,

    /// Audio encoding format such as .pcm (PCM integer) or .ieee_float (floating-point).
    format_code: z_wav.FormatCode,
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
///     .wave = .{ .bits = 16, .format_code = .pcm },
/// });
/// l.installWave(b, wave);
/// ```
pub fn installWave(b: *std.Build, wave: *CompileWave) void {
    b.getInstallStep().dependOn(wave.step);
}

pub fn addPlay(b: *std.Build, wave: *CompileWave) void {
}
