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
    const frequency: f64 = 440.0;
    const sample_rate: f64 = 44100.0;
    const volume: f64 = 0.5;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        const phase = t * frequency;

        // Square wave: +1 for first half of cycle, -1 for second half
        // We use @mod to get the fractional part of the phase
        samples[i] = if (@mod(phase, 1.0) < 0.5) volume else -volume;
    }

    const wave = try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    var writer = file.writer(buf);

    try wave.write(.wav, &writer.interface, .{
        .bits = 16,
        .format_code = .pcm,
    });

    try writer.interface.flush();
    std.debug.print("✓ Generated square wave at 440 Hz\n", .{});
    std.debug.print("  Duty cycle: 50%\n", .{});
}
