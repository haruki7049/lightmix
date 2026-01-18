//! # Build-Time Generation - Compile-Time Audio
//!
//! This example demonstrates lightmix's build-time wave generation feature.
//! Instead of running an executable, the audio file is generated during the build process.
//!
//! ## What you'll learn:
//! - Using lightmix's build.zig integration
//! - Generating audio at compile-time
//! - The `createWave` build helper function
//!
//! ## How to use:
//! Run `zig build` (not `zig build run`!)
//! The WAV file will be generated and installed during the build.

const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

/// This function is called at build-time by the build system
/// It must be pub and match the signature expected by createWave
pub fn generate() !Wave {
    const allocator = std.heap.page_allocator;

    // Generate a two-tone sequence: C5 then E5
    const c5_data = generateSineData(523.25);
    const c5 = Wave.init(c5_data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    const e5_data = generateSineData(659.25);
    const e5 = Wave.init(e5_data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    // Mix the two tones together
    const result = c5.mix(e5, .{});

    return result;
}

fn generateSineData(frequency: f32) [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const radians_per_sec: f32 = frequency * 2.0 * std.math.pi;

    var result: [44100]f32 = undefined;
    for (result, 0..) |*sample, i| {
        const t = @as(f32, @floatFromInt(i)) / sample_rate;
        sample.* = 0.3 * @sin(radians_per_sec * t);
    }

    return result;
}
