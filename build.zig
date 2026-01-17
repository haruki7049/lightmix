const std = @import("std");
const l_wav = @import("lightmix_wav");

pub const Wave = @import("./src/wave.zig");
pub const Composer = @import("./src/composer.zig");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const with_debug_features = b.option(bool, "with_debug_features", "Enable debug features implemented by PortAudio") orelse false;

    // Dependencies
    const lightmix_wav = b.dependency("lightmix_wav", .{});

    // Library module declaration
    const lib_mod = b.addModule("lightmix", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix_wav", .module = lightmix_wav.module("lightmix_wav") },
        },
    });

    // Library installation
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lightmix",
        .root_module = lib_mod,
    });

    if (with_debug_features)
        lib.linkLibC();

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

/// Creates a build step to play a Wave file instantly for debugging purposes.
///
/// This function generates a temporary Wave file in `.zig-cache/lightmix/` and
/// creates a system command to play it using the specified audio player command.
///
/// ## Parameters
/// - `b`: The Build instance
/// - `wave`: The Wave object to be played
/// - `options`: Configuration options for the debug play step
///
/// ## Returns
/// Returns a pointer to the Step that can be added to the build graph or executed.
///
/// ## Example
/// ```zig
/// const wave: lightmix.Wave = try generateWave();
/// const play_step = try lightmix.addDebugPlayStep(b, wave, .{
///     .step = .{ .name = "play", .description = "Play the generated wave" },
///     .command = &[_][]const u8{ "aplay" }, // Linux audio player
///     .wave = .{ .name = "debug.wav", .bit_type = .i16 },
/// });
/// // Run with: zig build play
/// ```
pub fn addDebugPlayStep(
    b: *std.Build,
    wave: Wave,
    comptime options: DebugPlayOptions,
) !*std.Build.Step {
    // Create a wave file in .zig-cache/lightmix
    const tmp_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ "lightmix", options.wave.name });

    var file = try b.cache_root.handle.createFile(tmp_path, .{});
    defer file.close();

    // Write the Wave data to the wave file
    try wave.write(file, options.wave.bit_type);

    const tmp_full_path: []const u8 = try b.cache_root.handle.realpathAlloc(b.allocator, tmp_path);
    const run = b.addSystemCommand(options.command);
    run.addArg(tmp_full_path);

    const result = b.step(options.step.name, options.step.description);
    result.dependOn(&run.step);

    return result;
}

/// Options for configuring a debug play build step.
///
/// This struct configures how a Wave file should be generated and played
/// during development for immediate audio feedback.
pub const DebugPlayOptions = struct {
    /// Configuration for the build step (name and description)
    step: StepOptions,
    /// Command to execute for playing the audio file (e.g., &[_][]const u8{"aplay"})
    command: []const []const u8,
    /// Configuration for the wave file (name and bit type)
    wave: WavefileOptions,
};

/// Options for configuring a build step's metadata.
///
/// This struct specifies the name and description of a custom build step.
pub const StepOptions = struct {
    /// The name of the build step (used with `zig build <name>`)
    name: []const u8 = "debug-play",
    /// Human-readable description shown in `zig build --help`
    description: []const u8 = "Play your wave instantly",
};

/// Creates a build step to install a Wave file to the output directory.
///
/// This function writes a Wave object to a temporary file in `.zig-cache/lightmix/`,
/// then creates an InstallFile step to copy it to the specified destination.
///
/// ## Parameters
/// - `b`: The Build instance
/// - `wave`: The Wave object to be written to a file
/// - `options`: Configuration options for the wave file generation
///
/// ## Returns
/// Returns a pointer to the InstallFile step that can be added to the build graph.
///
/// ## Example
/// ```zig
/// const wave: lightmix.Wave = try generateWave();
/// const wave_install_file = try lightmix.addWaveInstallFile(b, wave, .{
///     .wave = .{ .name = "output.wav", .bit_type = .i16 },
///     .path = .{ .custom = "share" }, // I like this path to install Wave file. This value is the default
///     //.path = .prefix, // You can customize it by following std.Build.InstallDir type
/// });
/// b.getInstallStep().dependOn(&wave_install_file.step);
/// ```
pub fn addWaveInstallFile(
    b: *std.Build,
    wave: Wave,
    comptime options: EmitWaveOptions,
) !*std.Build.Step.InstallFile {
    // Create .zig-cache/lightmix directory
    b.cache_root.handle.access("lightmix", .{}) catch {
        try b.cache_root.handle.makeDir("lightmix");
    };

    // Create a wave file in .zig-cache/lightmix
    const tmp_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ "lightmix", options.wave.name });
    var file = try b.cache_root.handle.createFile(tmp_path, .{});
    defer file.close();

    // Write the Wave data to the wave file
    try wave.write(file, options.wave.bit_type);

    // Create *std.Build.Step.InstallFile
    const src_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ ".zig-cache", "lightmix", options.wave.name });
    const result = b.addInstallFileWithDir(b.path(src_path), options.path, options.wave.name);
    return result;
}

/// Options for emitting a Wave file during the build process.
///
/// This struct configures how a Wave file should be generated and installed.
pub const EmitWaveOptions = struct {
    /// Configuration for the wave file (name and bit type)
    wave: WavefileOptions,
    /// Destination path relative to the install prefix
    path: std.Build.InstallDir = .{ .custom = "share" },
    /// Name of the generator function (used for legacy purposes)
    fn_name: []const u8 = "generate",
};

/// Options for configuring a wave file's properties.
///
/// This struct specifies the output filename and bit depth for the wave file.
pub const WavefileOptions = struct {
    /// The output filename for the wave file
    name: []const u8 = "result.wav",
    /// The bit depth for the wave file (e.g., .i16, .f32)
    bit_type: l_wav.BitType,
};

pub fn createWave(
    b: *std.Build,
    mod: *std.Build.Module,
    options: CreateWaveOptions,
) !*std.Build.Step {
    // Create .zig-cache/lightmix directory
    b.cache_root.handle.access("lightmix", .{}) catch {
        try b.cache_root.handle.makeDir("lightmix");
    };

    // Create a wave file in .zig-cache/lightmix
    const tmp_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ ".zig-cache", "lightmix", options.wave.name });
    // Generate temporary Zig code that calls the user's function
    const gen_source = try std.fmt.allocPrint(b.allocator,
        \\const std = @import("std");
        \\const user_module = @import("user_module");
        \\
        \\pub fn main() !void {{
        \\    const wave = try user_module.{s}();
        \\    defer wave.deinit();
        \\
        \\    var file = try std.fs.cwd().createFile("{s}", .{{}});
        \\    defer file.close();
        \\
        \\    try wave.write(file, .{s});
        \\}}
    , .{
        options.func_name,
        tmp_path,
        @tagName(options.wave.bit_type),
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

    return &install_wave.step;
}

pub const CreateWaveOptions = struct {
    /// Name of the function in the module that generates the Wave.
    /// The function must have signature: `pub fn name() !lightmix.Wave`
    func_name: []const u8 = "gen",

    /// Destination path relative to the install prefix
    path: std.Build.InstallDir = .{ .custom = "share" },

    /// Configuration for the wave file (name and bit type)
    wave: WavefileOptions,
};
