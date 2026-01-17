//! Synths Package
//!
//! This package provides audio synthesis engines (synthesizers).
//! Each synthesizer generates audio waveforms at specified pitches and durations.
//!
//! Currently, only a sine wave oscillator is provided, but other waveforms
//! such as square wave, sawtooth wave, and triangle wave can be added in the future.

/// Sine Wave Synthesizer
///
/// Generates pure sine waves at specified pitches.
/// A sine wave is the most basic waveform and is a pure tone without harmonics.
pub const Sine = @import("./synths/sine.zig");
