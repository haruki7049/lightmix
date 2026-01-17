const std = @import("std");
const lightmix = @import("lightmix");
const temperaments = @import("temperaments");

const Wave = lightmix.Wave;
const Scale = temperaments.TwelveEqualTemperament;

pub fn gen(
    allocator: std.mem.Allocator,
    length: usize,
    sample_rate: u32,
    channels: u16,
    scale: Scale,
) !Wave {
    var samples = try allocator.alloc(f32, length);

    for (0..samples.len) |i| {
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        samples[i] = @sin(t * scale.gen() * 2.0 * std.math.pi);
    }

    return Wave.init(samples, allocator, .{
        .sample_rate = sample_rate,
        .channels = channels,
    });
}
