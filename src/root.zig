//! # lightmix
//!
//! `lightmix` is an audio processing library written in Zig-lang.
//! This library provides powerful tools for audio generation, manipulation, and composition.
//!
//! ## Features
//!
//! - **Wave**: Generate and manipulate PCM audio samples with support for multiple channels and sample rates. Wave is a generic type function that accepts sample types (f64, f32, f80, f128).
//! - **Composer**: Compose multiple audio waves with precise timing control. Composer is also generic and works with Wave(T) instances.
//! - **Audio Filters**: Apply transformations to audio samples using custom filter functions
//! - **WAV File I/O**: Read and write WAV files with various bit depths and format codes
//! - **Audio Mixing**: Mix multiple audio sources together with customizable mixing functions
//!
//! ## Usage Example
//!
//! Here's a complete example that generates a sine wave, applies a decay filter,
//! and writes it to a WAV file:
//!
//! ```zig
//! const std = @import("std");
//! const lightmix = @import("lightmix");
//! const Wave = lightmix.Wave;
//!
//! pub fn main() !void {
//!     // Setup allocator
//!     var gpa = std.heap.GeneralPurposeAllocator(.{}){};
//!     defer _ = gpa.deinit();
//!     const allocator = gpa.allocator();
//!
//!     // Generate a 440Hz sine wave (1 second at 44.1kHz)
//!     const sample_rate: f64 = 44100.0;
//!     const frequency: f64 = 440.0;
//!     const radians_per_sec: f64 = frequency * 2.0 * std.math.pi;
//!
//!     var samples: [44100]f64 = undefined;
//!     for (samples, 0..) |*sample, i| {
//!         const t = @as(f64, @floatFromInt(i)) / sample_rate;
//!         sample.* = 0.5 * @sin(radians_per_sec * t);
//!     }
//!
//!     // Create a Wave from the generated samples using Wave(f64)
//!     const wave = Wave(f64).init(samples[0..], allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!
//!     // Apply a decay filter to create a fade-out effect
//!     // Note: filter() automatically frees the original wave, so no defer needed for 'wave'
//!     const decayed_wave = wave.filter(decay);
//!     defer decayed_wave.deinit();
//!
//!     // Write the result to a WAV file
//!     const file = try std.fs.cwd().createFile("output.wav", .{});
//!     defer file.close();
//!     try decayed_wave.write(file.writer(), .{
//!         .allocator = allocator,
//!         .bits = 16,
//!         .format_code = .pcm,
//!     });
//!
//!     std.debug.print("Audio file created successfully!\n", .{});
//! }
//!
//! fn decay(original_wave: Wave(f64)) !Wave(f64) {
//!     var result: std.array_list.Aligned(f64, null) = .empty;
//!
//!     for (original_wave.samples, 0..) |sample, n| {
//!         const i = original_wave.samples.len - n;
//!         const decay_factor = @as(f64, @floatFromInt(i)) * (1.0 / @as(f64, @floatFromInt(original_wave.samples.len)));
//!         const decayed_sample = sample * decay_factor;
//!         try result.append(original_wave.allocator, decayed_sample);
//!     }
//!
//!     return Wave(f64){
//!         .samples = try result.toOwnedSlice(original_wave.allocator),
//!         .allocator = original_wave.allocator,
//!         .sample_rate = original_wave.sample_rate,
//!         .channels = original_wave.channels,
//!     };
//! }
//! ```
//!
//! ## Getting Started
//!
//! To use lightmix in your project, add it as a dependency in your `build.zig.zon`.
//! You can find the specific commit hash and hash value from the releases page or
//! by using `zig fetch` command with the repository URL.
//!
//! Then import it in your `build.zig`:
//!
//! ```zig
//! const lightmix = b.dependency("lightmix", .{});
//! exe.root_module.addImport("lightmix", lightmix.module("lightmix"));
//! ```
//!
//! ## Build-time Utilities
//!
//! lightmix provides build.zig helper functions for generating Wave files at build time.
//! See `createWave()`, `CreateWaveOptions`, and `WavefileOptions` in the library's
//! build.zig for details on generating and installing Wave files as build artifacts.
//!
//! For more examples, see the [examples directory](https://github.com/haruki7049/lightmix/tree/main/examples).

pub const Wave = @import("./wave.zig").inner;
pub const Composer = @import("./composer.zig").inner;

test "Import tests" {
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
}
