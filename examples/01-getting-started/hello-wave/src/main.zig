//! # Hello Wave - Your First Audio with lightmix
//!
//! This is the simplest possible example using lightmix.
//! It creates a 1-second sine wave at 440Hz (musical note A4) and saves it to a WAV file.
//!
//! ## What you'll learn:
//! - How to generate audio samples
//! - How to create a Wave from samples
//! - How to save audio to a WAV file
//!
//! ## Run this example:
//! ```
//! zig build run
//! ```
//! This will create `result.wav` in the current directory.

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    // Use page allocator for simplicity
    // In production, consider using a more sophisticated allocator
    const allocator = std.heap.page_allocator;

    // Generate a 440Hz sine wave (A4 note)
    const frequency: f32 = 440.0;
    const sample_rate: f32 = 44100.0;
    const duration_seconds: f32 = 1.0;
    const num_samples: usize = @intFromFloat(sample_rate * duration_seconds);

    // Calculate radians per second for sine wave generation
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    // Generate the audio samples
    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = 0.5 * @sin(radians_per_sec * t); // 0.5 = volume control
    }

    // Create a Wave object from our samples
    const wave = Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1, // Mono audio
    });
    defer wave.deinit();

    // Save the wave to a WAV file
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    // Write as 16-bit integer PCM (most common format)
    try wave.write(file, .i16);

    std.debug.print("✓ Created result.wav - A 440Hz sine wave!\n", .{});
    std.debug.print("  Duration: 1 second\n", .{});
    std.debug.print("  Sample rate: 44100 Hz\n", .{});
    std.debug.print("  Format: 16-bit mono\n", .{});
}
