const std = @import("std");

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

    // Examples step - compile and run all examples
    const examples_step = b.step("examples", "Build and run all examples");
    addExamples(b, examples_step, lib_mod, target, optimize);

    // Docs
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "share/lightmix/docs",
    });
    docs_step.dependOn(&docs_install.step);
}

fn addExamples(b: *std.Build, examples_step: *std.Build.Step, lightmix_mod: *std.Build.Module, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const example_dirs = [_][]const u8{
        "examples/Composer/compose_multipul_sinewave",
        "examples/Composer/compose_multipul_soundless",
        "examples/Wave/generate_brown_noise",
        "examples/Wave/generate_double_frequency_wave",
        "examples/Wave/generate_function",
        "examples/Wave/generate_half_frequency_wave",
        "examples/Wave/generate_mix_wave",
        "examples/Wave/generate_pinknoise",
        "examples/Wave/generate_sawtooth_wave",
        "examples/Wave/generate_sinewave",
        "examples/Wave/generate_soundless",
        "examples/Wave/generate_square_wave",
        "examples/Wave/generate_triangle_wave",
        "examples/Wave/generate_whitenoise",
        "examples/Wave/generate_with_debug_play",
        "examples/Wave/generate_with_decay",
        "examples/drum/snare_drum",
        "examples/guitar/acoustic_guitar",
    };

    for (example_dirs) |example_dir| {
        const example_name = std.fs.path.basename(example_dir);
        addExample(b, examples_step, lightmix_mod, example_dir, example_name, target, optimize);
    }
}

fn addExample(
    b: *std.Build,
    examples_step: *std.Build.Step,
    lightmix_mod: *std.Build.Module,
    example_dir: []const u8,
    example_name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const main_path = b.fmt("{s}/src/main.zig", .{example_dir});

    // Create module for the example
    const example_mod = b.createModule(.{
        .root_source_file = b.path(main_path),
        .target = target,
        .optimize = optimize,
    });

    // Add lightmix import to the example module
    example_mod.addImport("lightmix", lightmix_mod);

    // Create executable for the example
    const example_exe = b.addExecutable(.{
        .name = example_name,
        .root_module = example_mod,
    });

    // Add to install step
    const install_example = b.addInstallArtifact(example_exe, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("examples/{s}", .{example_name}) } },
    });
    examples_step.dependOn(&install_example.step);

    // Add run step for the example
    const run_example = b.addRunArtifact(example_exe);
    run_example.step.dependOn(&install_example.step);

    examples_step.dependOn(&run_example.step);
}
