const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn gen(allocator: std.mem.Allocator) !Wave(f64) {
    // Generate a chord using const-compatible patterns
    const c5 = try generateSineWave(523.25, allocator); // C5
    defer c5.deinit();
    const e5 = try generateSineWave(659.25, allocator); // E5
    defer e5.deinit();
    const g5 = try generateSineWave(783.99, allocator); // G5
    defer g5.deinit();

    // Mix the three notes
    const ce_mix = try c5.mix(e5, .{});
    defer ce_mix.deinit();

    const chord = try ce_mix.mix(g5, .{});

    return chord;
}

fn generateSineWave(frequency: f64, allocator: std.mem.Allocator) !Wave(f64) {
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        samples[i] = 0.25 * @sin(radians_per_sec * t);
    }

    return try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
