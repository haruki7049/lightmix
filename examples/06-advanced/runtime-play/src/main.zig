//! # Runtime Audio Playback
//!
//! This example demonstrates real-time audio playback using lightmix.
//! A sine wave is synthesized and played directly through system speakers at runtime via `wave.play()`.
//!
//! ## What you'll learn:
//! - Using `wave.play()` for real-time audio playback
//! - Working with higher precision sample types like `f128`
//! - Direct audio output integration with system sound drivers
//!
//! ## Run this example:
//! ```
//! zig build run
//! ```

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    // Generate a 440Hz sine wave (A4 note)
    const frequency: f128 = 440.0;
    const sample_rate: f128 = 44100.0;
    const radians_per_sec: f128 = frequency * 2.0 * std.math.pi;
    const volume: f128 = 0.5;

    var samples: [44100]f128 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f128, @floatFromInt(i)) / sample_rate;
        // Sine wave formula: amplitude * sin(2π * frequency * time)
        samples[i] = volume * @sin(radians_per_sec * t);
    }

    const wave = try Wave(f128).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    try wave.play();
}
