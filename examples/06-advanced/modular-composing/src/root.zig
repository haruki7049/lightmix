const std = @import("std");
const lightmix = @import("lightmix");
const synths = @import("synths");

const Wave = lightmix.Wave;

pub fn gen(allocator: std.mem.Allocator) !Wave(f64) {
    return synths.Sine.gen(allocator, 44100, 44100, 1, .{ .code = .c, .octave = 4 });
}
