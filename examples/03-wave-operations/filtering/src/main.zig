//! # Filtering - Apply Multiple Transformations
//!
//! This example shows how to chain multiple filters together to transform audio.
//! We'll create a sine wave and apply decay, volume reduction, and distortion filters.
//!
//! ## What you'll learn:
//! - How to chain multiple filters
//! - Creating different types of audio effects
//! - Understanding filter composition

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate a sine wave
    const frequency: f32 = 440.0;
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = 0.8 * @sin(radians_per_sec * t);
    }

    const wave = Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    // Chain multiple filters together
    const filtered_wave = wave
        .filter(decayFilter)          // Apply fade-out
        .filter(halveSampleValuesFilter); // Reduce volume
    defer filtered_wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try filtered_wave.write(file, .i16);

    std.debug.print("✓ Applied multiple filters:\n", .{});
    std.debug.print("  1. Decay (fade-out)\n", .{});
    std.debug.print("  2. Volume reduction (50%%)\n", .{});
}

/// Decay filter: Linear fade-out effect
fn decayFilter(original_wave: Wave) !Wave {
    var result_list: std.array_list.Aligned(f32, null) = .empty;

    for (original_wave.samples, 0..) |sample, n| {
        const remaining = original_wave.samples.len - n;
        const decay_factor = @as(f32, @floatFromInt(remaining)) / 
                           @as(f32, @floatFromInt(original_wave.samples.len));
        try result_list.append(original_wave.allocator, sample * decay_factor);
    }

    return Wave{
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

/// Volume reduction filter: Halve all sample values
fn halveSampleValuesFilter(original_wave: Wave) !Wave {
    var result_list: std.array_list.Aligned(f32, null) = .empty;

    for (original_wave.samples) |sample| {
        try result_list.append(original_wave.allocator, sample * 0.5);
    }

    return Wave{
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}
