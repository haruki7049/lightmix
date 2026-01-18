//! # Triangle Wave - The Mellow Sound
//!
//! A triangle wave rises and falls linearly, producing a mellow sound.
//! It contains only odd harmonics (like a square wave), but they fall off faster,
//! making it softer and rounder than a square wave.
//!
//! ## What you'll learn:
//! - How to generate a triangle wave
//! - Piecewise linear function implementation
//! - Balancing between sine and square wave characteristics

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a 440Hz triangle wave
    const frequency: f32 = 440.0;
    const sample_rate: f32 = 44100.0;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        const phase = @mod(t * frequency, 1.0);
        
        // Triangle wave: rises from 0 to 1 in first half, falls from 1 to 0 in second half
        // Transform to -1 to +1 range
        sample.* = if (phase < 0.5)
            4.0 * phase - 1.0  // Rising: -1 to +1
        else
            3.0 - 4.0 * phase;  // Falling: +1 to -1
    }

    const wave = Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try wave.write(file, .i16);

    std.debug.print("✓ Generated triangle wave at 440 Hz\n", .{});
}
