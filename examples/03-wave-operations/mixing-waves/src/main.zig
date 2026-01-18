//! # Mixing Waves - Combining Multiple Audio Sources
//!
//! This example demonstrates how to mix (combine) multiple waves together.
//! We'll create a simple musical chord by mixing three sine waves at different frequencies.
//!
//! ## What you'll learn:
//! - How to use Wave.mix() to combine waves
//! - Creating musical chords from multiple frequencies
//! - Understanding additive synthesis
//!
//! ## Musical theory:
//! We'll create a C major chord (C4-E4-G4):
//! - C4: 261.63 Hz (root)
//! - E4: 329.63 Hz (major third)
//! - G4: 392.00 Hz (perfect fifth)

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate three notes of a C major chord
    const c4 = generateSineWave(261.63, 0.3, allocator); // C4 - root
    defer c4.deinit();
    const e4 = generateSineWave(329.63, 0.3, allocator); // E4 - major third
    defer e4.deinit();
    const g4 = generateSineWave(392.00, 0.3, allocator); // G4 - perfect fifth
    defer g4.deinit();

    // Mix the first two notes
    const c_e_mix = c4.mix(e4, .{});
    defer c_e_mix.deinit();

    // Mix in the third note to complete the chord
    const chord = c_e_mix.mix(g4, .{});
    defer chord.deinit();

    // Save the result
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try chord.write(file, .i16);

    std.debug.print("✓ Created C major chord (C4-E4-G4)\n", .{});
    std.debug.print("  C4: 261.63 Hz\n", .{});
    std.debug.print("  E4: 329.63 Hz\n", .{});
    std.debug.print("  G4: 392.00 Hz\n", .{});
}

fn generateSineWave(frequency: f32, volume: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = volume * @sin(radians_per_sec * t);
    }

    return Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
