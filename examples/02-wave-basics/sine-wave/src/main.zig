//! # Sine Wave - The Pure Tone
//!
//! A sine wave is the most fundamental waveform in audio synthesis.
//! It produces a pure tone with no harmonics, sounding very smooth and "electronic".
//!
//! ## What you'll learn:
//! - Mathematical formula for sine wave generation
//! - Relationship between frequency and pitch
//! - How sample rate affects audio quality
//!
//! ## Musical note in this example:
//! - A4: 440.0 Hz (standard tuning reference)

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a 440Hz sine wave (A4 note)
    const frequency: f32 = 440.0;
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;
    const volume: f32 = 0.5;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        // Sine wave formula: amplitude * sin(2π * frequency * time)
        sample.* = volume * @sin(radians_per_sec * t);
    }

    const wave = Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // Save to file
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try wave.write(file, .i16);

    std.debug.print("✓ Generated sine wave at 440 Hz\n", .{});
}
