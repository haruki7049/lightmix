const std = @import("std");
const lightmix = @import("lightmix");
const synths = @import("synths");

const Wave = lightmix.Wave;

pub fn gen(init: std.process.Init) !Wave(f64) {
    const allocator = init.arena.allocator();
    return synths.Sine.gen(allocator, 44100, 44100, 1, .{ .code = .c, .octave = 4 });
}
