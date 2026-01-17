const std = @import("std");
const lightmix = @import("lightmix");

const Wave = lightmix.Wave;

pub fn gen() !Wave {
    const allocator = std.heap.page_allocator;
    var samples: [44100]f32 = undefined;

    for (0..samples.len) |i| {
        const t = @as(f32, @floatFromInt(i)) / 44100.0;
        samples[i] = @sin(t * 440.0 * 2.0 * std.math.pi);
    }

    return lightmix.Wave.init(&samples, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
