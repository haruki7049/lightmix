//! # Sawtooth Wave - The Bright Sound
//!
//! A sawtooth wave has a linear rise and sharp fall, creating a bright, harsh sound.
//! It's rich in both odd and even harmonics, making it useful for brass and string synthesis.
//!
//! ## What you'll learn:
//! - How to generate a sawtooth wave using modulo operation
//! - Understanding harmonic richness
//! - Applications in synthesis

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a 440Hz sawtooth wave
    const frequency: f32 = 440.0;
    const sample_rate: f32 = 44100.0;
    const period: f32 = sample_rate / frequency;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        // Calculate position within the current period (0.0 to 1.0)
        const phase = @mod(@as(f32, @floatFromInt(i)), period) / period;
        
        // Sawtooth wave: Linear ramp from -1 to +1
        sample.* = (phase * 2.0) - 1.0;
    }

    const wave = Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try wave.write(file, .i16);

    std.debug.print("✓ Generated sawtooth wave at 440 Hz\n", .{});
}
