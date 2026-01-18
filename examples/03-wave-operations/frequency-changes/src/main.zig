//! # Frequency Changes - Pitch Shifting
//!
//! This example demonstrates techniques for changing the pitch of audio:
//! - Doubling frequency (one octave up)
//! - Halving frequency (one octave down)
//!
//! ## What you'll learn:
//! - How frequency relates to pitch
//! - Simple pitch shifting techniques
//! - Octave relationships in music

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate original 440Hz sine wave (A4)
    const original = generateSineWave(440.0, allocator);
    defer original.deinit();

    // One octave higher (880Hz - A5)
    const octave_up = generateSineWave(880.0, allocator);
    defer octave_up.deinit();

    // One octave lower (220Hz - A3)
    const octave_down = generateSineWave(220.0, allocator);
    defer octave_down.deinit();

    try saveWave(original, "a4_original.wav");
    try saveWave(octave_up, "a5_octave_up.wav");
    try saveWave(octave_down, "a3_octave_down.wav");

    std.debug.print("✓ Generated frequency variations:\n", .{});
    std.debug.print("  a4_original.wav - 440 Hz (A4)\n", .{});
    std.debug.print("  a5_octave_up.wav - 880 Hz (A5, +1 octave)\n", .{});
    std.debug.print("  a3_octave_down.wav - 220 Hz (A3, -1 octave)\n", .{});
}

fn generateSineWave(frequency: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = 0.5 * @sin(radians_per_sec * t);
    }

    return Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn saveWave(wave: Wave, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try wave.write(file, .i16);
}
