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
    const frequency: f64 = 440.0;
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;
    const volume: f64 = 0.5;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        // Sine wave formula: amplitude * sin(2π * frequency * time)
        samples[i] = volume * @sin(radians_per_sec * t);
    }

    const wave = try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // Save to file
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    try wave.write(&writer.interface, .{
        .allocator = allocator,
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Generated sine wave at 440 Hz\n", .{});
}
