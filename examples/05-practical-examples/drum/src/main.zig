//! # Drum Synthesis - Snare Drum
//!
//! This example creates a snare drum sound by combining:
//! - Pink noise (for the "snare" wire rattle)
//! - Sine wave (for the drum shell resonance)
//! - Decay envelopes (for the percussive attack)
//!
//! ## What you'll learn:
//! - Combining different sound sources for synthesis
//! - Using noise for percussion sounds
//! - Envelope shaping for realistic drums

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const snare_wave = generateSnare(allocator);
    defer snare_wave.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    try snare_wave.write(&writer.interface, .{
        .allocator = allocator,
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    std.debug.print("✓ Generated snare drum sound\n", .{});
}

fn generateSnare(allocator: std.mem.Allocator) Wave(f64) {
    // Generate pink noise for snare wires
    const noise = generatePinkNoise(allocator);

    // Generate low sine for drum body
    const tone = generateDrumTone(allocator);

    // Apply aggressive decay to noise
    const decayed_noise = noise
        .filter(fastDecayFilter)
        .filter(fastDecayFilter)
        .filter(fastDecayFilter);
    defer decayed_noise.deinit();

    // Apply decay to tone
    const decayed_tone = tone
        .filter(fastDecayFilter)
        .filter(halveSampleValuesFilter);
    defer decayed_tone.deinit();

    // Mix together
    return decayed_noise.mix(decayed_tone, .{});
}

fn generatePinkNoise(allocator: std.mem.Allocator) Wave(f64) {
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    var b0: f64 = 0.0;
    var b1: f64 = 0.0;
    var b2: f64 = 0.0;

    var samples: [22050]f64 = undefined; // 0.5 seconds
    for (0..samples.len) |i| {
        const white = rand.float(f64) * 2.0 - 1.0;
        b0 = 0.99765 * b0 + white * 0.0990460;
        b1 = 0.96300 * b1 + white * 0.2965164;
        b2 = 0.57000 * b2 + white * 1.0526913;
        samples[i] = (b0 + b1 + b2 + white * 0.1848) * 0.3;
    }

    return Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn generateDrumTone(allocator: std.mem.Allocator) Wave(f64) {
    const frequency: f64 = 200.0; // Low frequency for drum body
    const sample_rate: f64 = 44100.0;
    const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;

    var samples: [22050]f64 = undefined;
    for (0..samples.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / sample_rate;
        samples[i] = 0.4 * @sin(radians_per_sec * t);
    }

    return Wave(f64).init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn fastDecayFilter(original_wave: Wave(f64)) !Wave(f64) {
    var result_list: std.array_list.Aligned(f64, null) = .empty;

    for (original_wave.samples, 0..) |sample, n| {
        const remaining = original_wave.samples.len - n;
        const decay_factor = @as(f64, @floatFromInt(remaining)) /
            @as(f64, @floatFromInt(original_wave.samples.len));
        try result_list.append(original_wave.allocator, sample * decay_factor);
    }

    return Wave(f64){
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

fn halveSampleValuesFilter(original_wave: Wave(f64)) !Wave(f64) {
    var result_list: std.array_list.Aligned(f64, null) = .empty;

    for (original_wave.samples) |sample| {
        try result_list.append(original_wave.allocator, sample * 0.5);
    }

    return Wave(f64){
        .samples = try result_list.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}
