//! Sine Wave Synthesizer
//!
//! This module implements a synthesizer that generates pure sine waves.
//! A sine wave is the most basic waveform and is a pure tone with only a single frequency component.
//!
//! ## Features
//! - Pure tone without harmonics
//! - Same tone as a tuning fork or sine wave oscillator
//! - Fundamental waveform for acoustics and synthesizers

const std = @import("std");
const lightmix = @import("lightmix");
const temperaments = @import("temperaments");

const Wave = lightmix.Wave;
const Scale = temperaments.TwelveEqualTemperament;

/// Generate a sine wave at the specified pitch
///
/// This function generates sine wave audio data based on the given pitch (scale).
/// The generated waveform is in the form y = sin(2πft), where f is the frequency
/// calculated from the pitch.
///
/// ## Arguments
/// - `allocator`: Memory allocator (used to manage generated sample data)
/// - `length`: Number of samples to generate (e.g., 44100 samples for 1 second at 44.1kHz)
/// - `sample_rate`: Sampling rate (Hz). Common values are 44100 (CD quality) or 48000
/// - `channels`: Number of channels (1=mono, 2=stereo)
/// - `scale`: Pitch (including note name and octave)
///
/// ## Returns
/// - `Wave`: A Wave object containing the generated sine wave audio data
///
/// ## Errors
/// - Returns an error if memory allocation fails
///
/// ## Example
/// ```zig
/// const allocator = std.heap.page_allocator;
/// const scale = Scale{ .code = .a, .octave = 4 }; // A4 (440Hz)
/// const wave = try Sine.gen(allocator, 44100, 44100, 1, scale);
/// defer wave.deinit();
/// ```
pub fn gen(
    allocator: std.mem.Allocator,
    length: usize,
    sample_rate: u32,
    channels: u16,
    scale: Scale,
) !Wave {
    // Allocate sample data for the specified length
    var samples = try allocator.alloc(f32, length);

    // Calculate sine wave values at each sample point
    for (0..samples.len) |i| {
        // Calculate time t (in seconds)
        // t = sample index / sampling rate
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        
        // Calculate sine wave: sin(2πft)
        // scale.gen() gets the frequency f
        // 2πft is the phase in radians
        samples[i] = @sin(t * scale.gen() * 2.0 * std.math.pi);
    }

    // Initialize and return the Wave object
    return Wave.init(samples, allocator, .{
        .sample_rate = sample_rate,
        .channels = channels,
    });
}
