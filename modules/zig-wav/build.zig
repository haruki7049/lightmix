const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library module declaration
    const lib_mod = b.addModule("zig_wav", .{
        .root_source_file = b.path("src/wav.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library declaration
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "zig_wav",
        .root_module = lib_mod,
    });

    // Library installation
    b.installArtifact(lib);

    // Unit tests declaration
    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
