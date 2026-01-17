//! Modular Composing Example
//!
//! This module demonstrates how to generate audio using a modular architecture with lightmix.
//! It combines independent packages (temperaments and synths) to generate a sine wave
//! at C4 (middle C).

const std = @import("std");
const lightmix = @import("lightmix");
const synths = @import("synths");

const Wave = lightmix.Wave;

/// Generate an audio waveform
///
/// This function generates a sine wave at C4 (middle C, MIDI number 60, approximately 261.63Hz)
/// for 1 second.
///
/// ## Returns
/// - `Wave`: The generated audio waveform data
///
/// ## Errors
/// - Returns an error if memory allocation fails
pub fn gen() !Wave {
    // Use page allocator for memory management
    const allocator = std.heap.page_allocator;
    
    // Call synths.Sine.gen to generate the sine wave
    // Arguments:
    //   - allocator: Memory allocator
    //   - length: 44100 samples (1 second at 44.1kHz)
    //   - sample_rate: 44100 Hz (CD quality)
    //   - channels: 1 (mono)
    //   - scale: C4 (middle C, octave 4)
    return synths.Sine.gen(allocator, 44100, 44100, 1, .{ .code = .c, .octave = 4 });
}
