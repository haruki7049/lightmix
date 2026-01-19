//! # Using Filters - Transform Your Audio
//!
//! This example demonstrates how to use filters to transform audio waves.
//! We'll create a sine wave and apply a decay filter to create a fade-out effect.
//!
//! ## What you'll learn:
//! - How to create custom filter functions
//! - How to apply filters to waves
//! - How filter chaining works
//!
//! ## Run this example:
//! ```
//! zig build run
//! ```

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a 440Hz sine wave
    const frequency: f64 = 440.0;
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        samples[i] = 0.5 * @sin(radians_per_sec * t);
    }

    const wave = Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    // Apply a decay filter to create a fade-out effect
    // Note: filter() consumes the original wave, so no defer needed
    const decayed_wave = wave.filter(decayFilter);
    defer decayed_wave.deinit();

    // Save the result
    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    try decayed_wave.write(&writer.interface, .{
        .allocator = allocator,
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Created result.wav with fade-out effect!\n", .{});
}

/// Decay filter: Creates a linear fade-out effect
/// The volume decreases from 100% to 0% over the duration of the wave
fn decayFilter(comptime T: type, original_wave: Wave(T)) !Wave(T) {
    var result_list: std.array_list.Aligned(T, null) = .empty;

    // Process each sample, applying a decay factor
    for (original_wave.samples, 0..) |sample, n| {
        // Calculate how far from the end we are
        const remaining_samples = original_wave.samples.len - n;

        // Decay factor: 1.0 at start, 0.0 at end
        const decay_factor = @as(T, @floatFromInt(remaining_samples)) /
            @as(T, @floatFromInt(original_wave.samples.len));

        // Apply the decay to the sample
        const decayed_sample = sample * decay_factor;
        try result_list.append(original_wave.allocator, decayed_sample);
    }

    // Return a new Wave with the filtered samples
    return Wave(T){
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}
