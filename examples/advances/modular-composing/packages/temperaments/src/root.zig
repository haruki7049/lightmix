//! Temperaments Package
//!
//! This package provides tuning systems (scale tuning systems).
//! A tuning system is a system that defines the relative frequency relationships
//! of pitches used in music.
//!
//! Currently, only Twelve Equal Temperament is provided, but other tuning systems
//! such as just intonation and Pythagorean tuning can be added in the future.

/// Twelve Equal Temperament
/// 
/// A tuning system that divides one octave into 12 equal semitones.
/// This is the most commonly used tuning system in Western music.
pub const TwelveEqualTemperament = @import("./twelve_equal_temperament.zig");
