const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});
    const synths = b.dependency("synths", .{});
    const temperaments = b.dependency("temperaments", .{});

    const mod = b.addModule("modular-composing", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
            .{ .name = "synths", .module = synths.module("synths") },
            .{ .name = "temperaments", .module = temperaments.module("temperaments") },
        },
    });
    const wave = try l.addWave(b, mod, .{
        .func_name = "gen",
        .wave = .{ .bits = 16, .format_code = .pcm },
    });
    l.installWave(b, wave);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
