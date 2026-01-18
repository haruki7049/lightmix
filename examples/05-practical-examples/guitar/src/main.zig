//! # Guitar Synthesis - Karplus-Strong Algorithm
//!
//! This example demonstrates the Karplus-Strong algorithm for plucked string synthesis.
//! It simulates a guitar-like sound by using noise excitation and feedback delay.
//!
//! ## What you'll learn:
//! - Physical modeling synthesis
//! - The Karplus-Strong algorithm
//! - Creating realistic instrument sounds
//!
//! ## How it works:
//! 1. Start with noise in a delay buffer
//! 2. Average adjacent samples and apply decay
//! 3. Feed back into the buffer
//! This creates a pitched, decaying sound like a plucked string!

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Generate guitar notes at different frequencies
    const e2 = generateGuitarNote(82.41, allocator);   // Low E string
    defer e2.deinit();
    
    const a2 = generateGuitarNote(110.00, allocator);  // A string
    defer a2.deinit();

    try saveWave(e2, "guitar_e2.wav");
    try saveWave(a2, "guitar_a2.wav");

    std.debug.print("✓ Generated guitar sounds:\n", .{});
    std.debug.print("  guitar_e2.wav - Low E string (82.41 Hz)\n", .{});
    std.debug.print("  guitar_a2.wav - A string (110.00 Hz)\n", .{});
}

/// Karplus-Strong guitar synthesis
fn generateGuitarNote(frequency: f32, allocator: std.mem.Allocator) Wave {
    const sample_rate: f32 = 44100.0;
    const decay: f32 = 0.996;  // Decay factor (close to 1 = longer sustain)
    const duration_samples: usize = 88200; // 2 seconds

    var result: [88200]f32 = undefined;

    // Calculate period in samples
    const period = @as(usize, @intFromFloat(sample_rate / frequency));
    
    // Initialize delay buffer with noise
    var buffer: [2000]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    for (buffer[0..period]) |*val| {
        val.* = rand.float(f32) * 2.0 - 1.0;
    }

    // Karplus-Strong loop: average adjacent samples with decay
    var idx: usize = 0;
    for (result, 0..) |*sample| {
        const next_idx = (idx + 1) % period;
        const avg = (buffer[idx] + buffer[next_idx]) * 0.5 * decay;
        buffer[idx] = avg;
        sample.* = avg * 0.8; // Volume adjustment
        idx = next_idx;
    }

    return Wave.init(result[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
}

fn saveWave(wave: Wave, filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(filename, .{});
    defer file.close();
    try wave.write(file, .i16);
}
