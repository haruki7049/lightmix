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
    const frequency: f64 = 440.0;
    const sample_rate: f64 = 44100.0;

    // Calculate radians per second for sine wave generation
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    // Generate the audio samples
    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        samples[i] = 0.5 * @sin(radians_per_sec * t); // 0.5 = volume control
    }

    // Create a Wave object from our samples
    const wave = try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1, // Mono audio
    });
    defer wave.deinit();

    // Save the wave to a WAV file
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    // Write as 16-bit integer PCM (most common format)
    try wave.write(.wav, &writer.interface, .{
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Created result.wav - A 440Hz sine wave!\n", .{});
    std.debug.print("  Duration: 1 second\n", .{});
    std.debug.print("  Sample rate: 44100 Hz\n", .{});
    std.debug.print("  Format: 16-bit mono\n", .{});
}
