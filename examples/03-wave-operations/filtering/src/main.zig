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
    const frequency: f64 = 440.0;
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        samples[i] = 0.8 * @sin(radians_per_sec * t);
    }

    var wave = try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    try wave.filter(decayFilter); // Apply fade-out
    try wave.filter(halveSampleValuesFilter); // Reduce volume
    defer wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    try wave.write(.wav, &writer.interface, .{
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Applied multiple filters:\n", .{});
    std.debug.print("  1. Decay (fade-out)\n", .{});
    std.debug.print("  2. Volume reduction (50%)\n", .{});
}

/// Decay filter: Linear fade-out effect
fn decayFilter(comptime T: type, original_wave: Wave(T)) !Wave(T) {
    var result_list: std.array_list.Aligned(T, null) = .empty;

    for (original_wave.samples, 0..) |sample, n| {
        const remaining = original_wave.samples.len - n;
        const decay_factor = @as(T, @floatFromInt(remaining)) /
            @as(T, @floatFromInt(original_wave.samples.len));
        try result_list.append(original_wave.allocator, sample * decay_factor);
    }

    return Wave(T){
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

/// Volume reduction filter: Halve all sample values
fn halveSampleValuesFilter(comptime T: type, original_wave: Wave(T)) !Wave(T) {
    var result_list: std.array_list.Aligned(T, null) = .empty;

    for (original_wave.samples) |sample| {
        try result_list.append(original_wave.allocator, sample * 0.5);
    }

    return Wave(T){
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}
