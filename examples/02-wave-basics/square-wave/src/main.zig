//! # Square Wave - The Digital Sound
//!
//! A square wave alternates between two values (high and low) with sharp transitions.
//! It produces a rich, buzzy sound with many odd harmonics, commonly used in retro video game music.
//!
//! ## What you'll learn:
//! - How to generate a square wave
//! - Understanding duty cycle (50% in this example)
//! - The characteristic "buzzy" sound of square waves
//!
//! ## Sound characteristics:
//! - Contains fundamental frequency + odd harmonics (3rd, 5th, 7th, etc.)
//! - Sharp, electronic, "8-bit" sound

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a 440Hz square wave
    const frequency: f32 = 440.0;
    const sample_rate: f32 = 44100.0;
    const volume: f32 = 0.5;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        const phase = t * frequency;
        
        // Square wave: +1 for first half of cycle, -1 for second half
        // We use @mod to get the fractional part of the phase
        sample.* = if (@mod(phase, 1.0) < 0.5) volume else -volume;
    }

    const wave = Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try wave.write(file, .i16);

    std.debug.print("✓ Generated square wave at 440 Hz\n", .{});
    std.debug.print("  Duty cycle: 50%%\n", .{});
}
