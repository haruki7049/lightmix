const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    const wave = try l.addWave(b, mod, .{
        // .func_name = "gen", // The default value of func_name is "gen"
        .wave = .{ .bits = 16, .format_code = .pcm },
    });
    l.installWave(b, wave);

    const play_wave = l.addPlay(wave);
    const play_step = b.step("play", "Play produced Wave file");
    play_step.dependOn(&play_wave.step);

    // Unit tests
    const unit_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Test step
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
