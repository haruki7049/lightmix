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
) !Wave(f64) {
    // Allocate sample data for the specified length
    var samples = try allocator.alloc(f64, length);

    // Calculate sine wave values at each sample point
    for (0..samples.len) |i| {
        // Calculate time t (in seconds)
        // t = sample index / sampling rate
        const t = @as(f64, @floatFromInt(i)) / @as(f64, @floatFromInt(sample_rate));

        // Calculate sine wave: sin(2πft)
        // scale.gen() gets the frequency f
        // 2πft is the phase in radians
        samples[i] = @sin(t * scale.gen() * 2.0 * std.math.pi);
    }

    // Initialize and return the Wave object
    return Wave(f64){
        .samples = samples,
        .allocator = allocator,
        .sample_rate = sample_rate,
        .channels = channels,
    };
}
