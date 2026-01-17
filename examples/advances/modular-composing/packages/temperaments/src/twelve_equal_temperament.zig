//! Twelve equal temperament

const std = @import("std");
const testing = std.testing;

const Self = @This();

code: Code,
octave: usize,

pub fn add(self: Self, semitones: isize) Self {
    const self_midi_number: isize = @intCast(12 * (self.octave + 1) + @intFromEnum(self.code));
    const result_midi_number: isize = self_midi_number + semitones;

    const result_code: Code = @enumFromInt(@as(u8, @intCast(@mod(result_midi_number, 12))));
    const result_octave: usize = @intCast(@divTrunc(result_midi_number, 12) - 1);

    return Self{
        .code = result_code,
        .octave = result_octave,
    };
}

pub fn gen(scale: Self) f32 {
    const midi_number: isize = @intCast(12 * (scale.octave + 1) + @intFromEnum(scale.code));
    const exp: f32 = @floatFromInt(midi_number - 69);
    const result: f32 = 440.0 * std.math.pow(f32, 2.0, exp / 12.0);
    return result;
}

/// Codes written by English.
/// The `~s` code means the tone with sharp.
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
