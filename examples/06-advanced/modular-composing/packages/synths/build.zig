const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});
    const temperaments = b.dependency("temperaments", .{});

    const mod = b.addModule("synths", .{
        .root_source_file = b.path("src/synths.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
            .{ .name = "temperaments", .module = temperaments.module("temperaments") },
        },
    });

    // Install lib as a static library
    const lib = b.addLibrary(.{
        .name = "synths",
        .root_module = mod,
    });
    b.installArtifact(lib);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
