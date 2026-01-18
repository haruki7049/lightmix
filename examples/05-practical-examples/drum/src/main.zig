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
    try snare_wave.write(file, .i16);

    std.debug.print("✓ Generated snare drum sound\n", .{});
}

fn generateSnare(allocator: std.mem.Allocator) Wave {
    // Generate pink noise for snare wires
    const noise = generatePinkNoise(allocator);
    defer noise.deinit();
    
    // Generate low sine for drum body
    const tone = generateDrumTone(allocator);
    defer tone.deinit();

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

fn generatePinkNoise(allocator: std.mem.Allocator) Wave {
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    var b0: f32 = 0.0;
    var b1: f32 = 0.0;
    var b2: f32 = 0.0;

    var samples: [22050]f32 = undefined; // 0.5 seconds
    for (samples) |*sample| {
        const white = rand.float(f32) * 2.0 - 1.0;
        b0 = 0.99765 * b0 + white * 0.0990460;
        b1 = 0.96300 * b1 + white * 0.2965164;
        b2 = 0.57000 * b2 + white * 1.0526913;
        sample.* = (b0 + b1 + b2 + white * 0.1848) * 0.3;
    }

    return Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn generateDrumTone(allocator: std.mem.Allocator) Wave {
    const frequency: f32 = 200.0; // Low frequency for drum body
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    var samples: [22050]f32 = undefined;
    for (samples, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = 0.4 * @sin(radians_per_sec * t);
    }

    return Wave.init(samples[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn fastDecayFilter(original_wave: Wave) !Wave {
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
