const std = @import("std");
const lightmix = @import("lightmix");
const RootOptions = @import("./src/root.zig").Options;

pub fn build(b: *std.Build) !void {
    const root = @import("./src/root.zig");

    const wave: *std.Build.Step.InstallFile = try lightmix.addWaveInstallFile(b, root, RootOptions, .{
        .args = .{ .example_option = 7 },
        .wave = .{ .name = "result.wav", .bit_type = .i16 },
        .path = "share",
    });

    b.default_step = &wave.step;
}

const Options = struct {
    option: u8,
};
