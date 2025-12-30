const std = @import("std");
const lightmix = @import("lightmix");
const RootOptions = @import("./src/root.zig").Options;

pub fn build(b: *std.Build) !void {
    const root = @import("./src/root.zig");

    const wave: lightmix.Wave = try root.generate(.{ .example_option = 7 });

    const wave_install_file: *std.Build.Step.InstallFile = try lightmix.addWaveInstallFile(b, wave, .{
        .wave = .{ .name = "result.wav", .bit_type = .i16 },
        .path = .{ .custom = "share" },
    });

    const debug_play_step = try lightmix.addDebugPlayStep(b, wave, .{
        .step = .{ .name = "debug", .description = "Play your wave instantly" },
        .command = &[_][]const u8{"play"},
        .wave = .{ .name = "result.wav", .bit_type = .i16 },
    });

    debug_play_step.dependOn(&wave_install_file.step);
    b.default_step = &wave_install_file.step;
}

const Options = struct {
    option: u8,
};
