//! # Modular Architecture - Organizing Complex Audio Projects
//!
//! This example demonstrates a modular approach to organizing audio code.
//! While simple for demonstration, this pattern scales well for larger projects.
//!
//! ## What you'll learn:
//! - Organizing code into modules
//! - Separating synthesis logic from composition
//! - Building reusable audio components
//!
//! ## Structure:
//! - Generators module: Reusable wave generators
//! - Envelopes module: Reusable envelope functions
//! - Main: Composition using the modules

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Use modular generators to create sounds
    const kick = Generators.kick(allocator);
    defer kick.deinit();

    const hihat = Generators.hihat(allocator);
    defer hihat.deinit();

    // Process with envelope
    const shaped_kick = kick.filter(Envelopes.exponentialDecay);
    defer shaped_kick.deinit();

    const shaped_hihat = hihat.filter(Envelopes.fastDecay);
    defer shaped_hihat.deinit();

    // Mix together
    const drum_mix = shaped_kick.mix(shaped_hihat, .{});
    defer drum_mix.deinit();

    const file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();
    try drum_mix.write(file, .i16);

    std.debug.print("✓ Generated modular drum pattern\n", .{});
}

/// Module containing reusable wave generators
const Generators = struct {
    /// Generate a kick drum sound (low sine with pitch envelope)
    pub fn kick(allocator: std.mem.Allocator) Wave {
        const sample_rate: f32 = 44100.0;
        const start_freq: f32 = 150.0;
        const end_freq: f32 = 40.0;

        var samples: [11025]f32 = undefined; // 0.25 seconds
        for (samples, 0..) |*sample, i| {
            const t = @as(f32, @floatFromInt(i)) / sample_rate;
            const progress = t / 0.25;
            
            // Frequency sweep from high to low
            const freq = start_freq + (end_freq - start_freq) * progress;
            const radians_per_sec = freq * 2.0 * std.math.pi;
            
            sample.* = 0.7 * @sin(radians_per_sec * t);
        }

        return Wave.init(samples[0..], allocator, .{
            .sample_rate = 44100,
            .channels = 1,
        });
    }

    /// Generate a hi-hat sound (filtered noise)
    pub fn hihat(allocator: std.mem.Allocator) Wave {
        var prng = std.Random.DefaultPrng.init(42);
        const rand = prng.random();

        var samples: [4410]f32 = undefined; // 0.1 seconds
        for (samples) |*sample| {
            // High-passed white noise
            sample.* = (rand.float(f32) * 2.0 - 1.0) * 0.3;
        }

        return Wave.init(samples[0..], allocator, .{
            .sample_rate = 44100,
            .channels = 1,
        });
    }
};

/// Module containing reusable envelope functions
const Envelopes = struct {
    pub fn exponentialDecay(wave: Wave) !Wave {
        var result_list: std.array_list.Aligned(f32, null) = .empty;

        for (wave.samples, 0..) |sample, i| {
            const progress = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(wave.samples.len));
            const envelope = @exp(-4.0 * progress); // Exponential decay
            try result_list.append(wave.allocator, sample * envelope);
        }

        return Wave{
            .samples = try result_list.toOwnedSlice(wave.allocator),
            .allocator = wave.allocator,
            .sample_rate = wave.sample_rate,
            .channels = wave.channels,
        };
    }

    pub fn fastDecay(wave: Wave) !Wave {
        var result_list: std.array_list.Aligned(f32, null) = .empty;

        for (wave.samples, 0..) |sample, n| {
            const remaining = wave.samples.len - n;
            const decay = @as(f32, @floatFromInt(remaining)) / @as(f32, @floatFromInt(wave.samples.len));
            try result_list.append(wave.allocator, sample * decay);
        }

        return Wave{
            .samples = try result_list.toOwnedSlice(wave.allocator),
            .allocator = wave.allocator,
            .sample_rate = wave.sample_rate,
            .channels = wave.channels,
        };
    }
};
