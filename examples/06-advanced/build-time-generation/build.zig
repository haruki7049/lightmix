const std = @import("std");
const lightmix_build = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});

    // Create a module that contains our generate() function
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    // Use lightmix's build-time wave generation
    // This calls the generate() function at build-time and creates result.wav
    const wave_step: *std.Build.Step = try lightmix_build.createWave(b, mod, .{ 
        .func_name = "generate", 
        .wave = .{ .bit_type = .i16 } 
    });
    b.getInstallStep().dependOn(wave_step);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
}
