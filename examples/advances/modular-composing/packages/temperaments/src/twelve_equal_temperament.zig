//! Twelve Equal Temperament
//!
//! This module implements twelve equal temperament.
//! Twelve equal temperament is a tuning system that divides one octave into 12 equal semitones,
//! with each semitone having a frequency ratio of 2^(1/12). This allows the same pitch relationships
//! to be maintained in any key (allowing free transposition).
//!
//! ## Usage Example
//! ```zig
//! const scale = TwelveEqualTemperament{ .code = .c, .octave = 4 };
//! const freq = scale.gen(); // Get the frequency of C4 (approximately 261.63 Hz)
//!
//! const d4 = scale.add(2); // Move to D4 (2 semitones up)
//! ```

const std = @import("std");
const testing = std.testing;

const Self = @This();

/// Note code (C, C#, D, etc.)
code: Code,

/// Octave number (4 for C4)
octave: usize,

/// Move the pitch by the specified number of semitones
///
/// ## Arguments
/// - `self`: Current pitch
/// - `semitones`: Number of semitones to move (positive for up, negative for down)
///
/// ## Returns
/// A new `Self` instance representing the moved pitch
///
/// ## Example
/// ```zig
/// const c4 = TwelveEqualTemperament{ .code = .c, .octave = 4 };
/// const e4 = c4.add(4); // E4, 4 semitones up from C4
/// const a3 = c4.add(-3); // A3, 3 semitones down from C4
/// ```
pub fn add(self: Self, semitones: isize) Self {
    // Convert current pitch to MIDI number (C-1 = 0, A4 = 69)
    const self_midi_number: isize = @intCast(12 * (self.octave + 1) + @intFromEnum(self.code));
    
    // Add semitones
    const result_midi_number: isize = self_midi_number + semitones;

    // Decompose MIDI number into note code and octave
    // Remainder of division by 12 is the note, quotient gives the octave
    const result_code: Code = @enumFromInt(@as(u8, @intCast(@mod(result_midi_number, 12))));
    const result_octave: usize = @intCast(@divTrunc(result_midi_number, 12) - 1);

    return Self{
        .code = result_code,
        .octave = result_octave,
    };
}

/// Calculate frequency (Hz) from pitch
///
/// Uses the frequency calculation formula for twelve equal temperament:
/// f = 440 * 2^((midi_number-69)/12)
/// where midi_number is the MIDI number, and 440Hz is the reference frequency for A4 (MIDI number 69).
///
/// ## Arguments
/// - `scale`: Pitch to calculate frequency for
///
/// ## Returns
/// Frequency of the pitch (Hz)
///
/// ## Example
/// ```zig
/// const a4 = TwelveEqualTemperament{ .code = .a, .octave = 4 };
/// const freq = a4.gen(); // 440.0 Hz
/// ```
pub fn gen(scale: Self) f32 {
    // Convert pitch to MIDI number
    const midi_number: isize = @intCast(12 * (scale.octave + 1) + @intFromEnum(scale.code));
    
    // Calculate semitone difference from A4 (MIDI number 69, 440Hz)
    const exp: f32 = @floatFromInt(midi_number - 69);
    
    // Twelve equal temperament formula: f = 440 * 2^((midi_number-69)/12)
    const result: f32 = 440.0 * std.math.pow(f32, 2.0, exp / 12.0);
    return result;
}

/// Note code
///
/// Codes with `~s` represent sharp (#).
/// Example: `cs` is C# (C sharp)
///
/// ## Note names and MIDI number mapping
/// - c (0): C
/// - cs (1): C♯
/// - d (2): D
/// - ds (3): D♯
/// - e (4): E
/// - f (5): F
/// - fs (6): F♯
/// - g (7): G
/// - gs (8): G♯
/// - a (9): A
/// - as (10): A♯
/// - b (11): B
pub const Code = enum(u8) {
    c = 0,
    cs = 1,
    d = 2,
    ds = 3,
    e = 4,
    f = 5,
    fs = 6,
    g = 7,
    gs = 8,
    a = 9,
    as = 10,
    b = 11,
};
