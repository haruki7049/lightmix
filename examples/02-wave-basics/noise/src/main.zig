//! # Noise - Random Audio Signals
//!
//! This example demonstrates three types of noise commonly used in audio:
//! - White Noise: Equal energy across all frequencies (like TV static)
//! - Pink Noise: Equal energy per octave (more natural, like rain)
//! - Brown Noise: Even more bass-heavy (like ocean waves)
//!
//! ## What you'll learn:
//! - Using random number generation for audio
//! - Different types of noise and their characteristics
//! - Filtering techniques for colored noise

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate different types of noise
    const white_noise = try generateWhiteNoise(allocator);
    defer white_noise.deinit();

    const pink_noise = try generatePinkNoise(allocator);
    defer pink_noise.deinit();

    const brown_noise = try generateBrownNoise(allocator);
    defer brown_noise.deinit();

    // Save each to a file
    try saveWave(white_noise, "white_noise.wav", allocator);
    try saveWave(pink_noise, "pink_noise.wav", allocator);
    try saveWave(brown_noise, "brown_noise.wav", allocator);

    std.debug.print("✓ Generated noise samples:\n", .{});
    std.debug.print("  white_noise.wav - Equal energy across frequencies\n", .{});
    std.debug.print("  pink_noise.wav - Equal energy per octave\n", .{});
    std.debug.print("  brown_noise.wav - Bass-heavy noise\n", .{});
}

/// White noise: completely random values
fn generateWhiteNoise(allocator: std.mem.Allocator) !Wave(f64) {
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        // Random value between -0.5 and +0.5
        samples[i] = (rand.float(f64) * 2.0 - 1.0) * 0.5;
    }

    return try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

/// Pink noise: filtered white noise with 1/f spectrum
fn generatePinkNoise(allocator: std.mem.Allocator) !Wave(f64) {
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    // Paul Kellett's refined method for pink noise
    var b0: f64 = 0.0;
    var b1: f64 = 0.0;
    var b2: f64 = 0.0;

    var samples: [44100]f64 = undefined;
    for (0..samples.len) |i| {
        const white = rand.float(f64) * 2.0 - 1.0;

        b0 = 0.99765 * b0 + white * 0.0990460;
        b1 = 0.96300 * b1 + white * 0.2965164;
        b2 = 0.57000 * b2 + white * 1.0526913;

        samples[i] = (b0 + b1 + b2 + white * 0.1848) * 0.15;
    }

    return try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

/// Brown noise: integrated white noise (random walk)
fn generateBrownNoise(allocator: std.mem.Allocator) !Wave(f64) {
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    var last_value: f64 = 0.0;
    var samples: [44100]f64 = undefined;

    for (0..samples.len) |i| {
        // Add small random step to previous value
        const step = (rand.float(f64) * 2.0 - 1.0) * 0.02;
        last_value += step;

        // Clamp to prevent drift
        last_value = @max(-1.0, @min(1.0, last_value));

        samples[i] = last_value * 0.5;
    }

    return try Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn saveWave(wave: Wave(f64), filename: []const u8, allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
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
}
