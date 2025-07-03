const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module declaration
    const lib_mod = b.addModule("lightmix", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library declaration
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "lightmix",
        .root_module = lib_mod,
    });

    // Install library artifact
    b.installArtifact(lib);

    // Library unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });

    // Add library artifact
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    // Docs step
    const docs_step = b.step("docs", "Emit docs");
    const docs_install = b.addInstallDirectory(.{
        .source_dir = lib.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "share/lightmix/docs",
    });
    docs_step.dependOn(&docs_install.step);
}
