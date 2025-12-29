const std = @import("std");
pub const Wave = @import("./src/wave.zig");
const l_wav = @import("lightmix_wav");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const with_debug_features = b.option(bool, "with_debug_features", "Enable debug features implemented by PortAudio") orelse false;

    const options = b.addOptions();
    options.addOption(bool, "with_debug_features", with_debug_features);

    // Dependencies
    const lightmix_wav = b.dependency("lightmix_wav", .{});
    const known_folders = b.dependency("known_folders", .{});

    // Library module declaration
    const lib_mod = b.addModule("lightmix", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("lightmix_wav", lightmix_wav.module("lightmix_wav"));
    lib_mod.addImport("known-folders", known_folders.module("known-folders"));
    lib_mod.addOptions("build_options", options);
    lib_mod.addOptions("with_debug_features", options);

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

    // Docs
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "share/lightmix/docs",
    });
    docs_step.dependOn(&docs_install.step);
}

pub fn addWaveInstallFile(
    b: *std.Build,
    comptime mod: type,
    comptime T: ?type,
    comptime options: EmitWaveOptions(T),
) !*std.Build.Step.InstallFile {
    var wave: Wave = undefined;

    if (T == null) {
        wave = try @field(mod, options.fn_name)();
    } else {
        wave = try @field(mod, options.fn_name)(options.args);
    }

    b.cache_root.handle.access("lightmix", .{}) catch {
        try b.cache_root.handle.makeDir("lightmix");
    };

    const tmp_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ "lightmix", options.wave.name });
    var file = try b.cache_root.handle.createFile(tmp_path, .{});
    defer file.close();

    try wave.write(file, options.wave.bit_type);

    const src_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ ".zig-cache", "lightmix", options.wave.name });
    const dest_path: []const u8 = try std.fs.path.join(b.allocator, &[_][]const u8{ options.path, options.wave.name });
    const result = b.addInstallFile(b.path(src_path), dest_path);
    return result;
}

pub fn EmitWaveOptions(comptime T: ?type) type {
    if (T == null) {
        return struct {
            wave: WavefileOptions,
            path: []const u8 = "",
            fn_name: []const u8 = "generate",
        };
    } else {
        return struct {
            args: T.?,
            wave: WavefileOptions,
            path: []const u8 = "",
            fn_name: []const u8 = "generate",
        };
    }
}

pub const WavefileOptions = struct {
    name: []const u8 = "result.wav",
    bit_type: l_wav.BitType,
};
