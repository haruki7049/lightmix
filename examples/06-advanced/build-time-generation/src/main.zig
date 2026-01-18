//! # Build-Time Generation - Programmatic Audio
//!
//! This example demonstrates generating audio programmatically using const functions.
//! While not strictly "compile-time" in Zig terms, it shows how to generate audio
//! data using comptime-compatible patterns.
//!
//! ## What you'll learn:
//! - Generating audio data in functions
//! - Const-compatible audio generation patterns
//! - Creating complex sounds programmatically
//!
//! ## Note:
//! The lightmix createWave() build helper is still evolving. This example uses
//! a standard runtime approach that's more stable for now.

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a chord using const-compatible patterns
    const c5 = generateSineWave(523.25, allocator); // C5
    const e5 = generateSineWave(659.25, allocator); // E5
    const g5 = generateSineWave(783.99, allocator); // G5

    // Mix the three notes
    const ce_mix = c5.mix(e5, .{});
    defer ce_mix.deinit();

    const chord = ce_mix.mix(g5, .{});
    defer chord.deinit();

    // Save result
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try chord.write(file, .i16);

    std.debug.print("✓ Generated C major chord programmatically\n", .{});
    std.debug.print("  Notes: C5, E5, G5\n", .{});
}

fn generateSineWave(frequency: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = 0.25 * @sin(radians_per_sec * t);
    }

    return Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}
