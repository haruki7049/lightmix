const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies
    const zig_wav = b.dependency("zig_wav", .{});

    // Library module declaration
    const lib_mod = b.addModule("lightmix", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zig_wav", zig_wav.module("zig_wav"));

    // Executable module declaration
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("zig_wav", zig_wav.module("zig_wav"));
    exe_mod.addImport("lightmix_lib", lib_mod);

    // Library installation
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lightmix",
        .root_module = lib_mod,
    });
    b.installArtifact(lib);

    // Executable installation
    const exe = b.addExecutable(.{
        .name = "lightmix",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    // Run cmd
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Run step
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Library unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Executable unit tests
    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
