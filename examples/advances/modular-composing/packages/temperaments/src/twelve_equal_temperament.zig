//! Twelve Equal Temperament (十二平均律)
//!
//! このモジュールは十二平均律を実装しています。
//! 十二平均律は、1オクターブを12の等しい半音に分割する音律システムで、
//! 各半音の周波数比は2^(1/12)です。これにより、どの調でも同じ音程関係を
//! 保つことができます（転調が自由）。
//!
//! ## 使用例
//! ```zig
//! const scale = TwelveEqualTemperament{ .code = .c, .octave = 4 };
//! const freq = scale.gen(); // C4の周波数（約261.63 Hz）を取得
//!
//! const d4 = scale.add(2); // D4に移動（2半音上）
//! ```

const std = @import("std");
const testing = std.testing;

const Self = @This();

/// 音名コード（C, C#, D, ...など）
code: Code,

/// オクターブ番号（C4の場合は4）
octave: usize,

/// 指定した半音数だけ音程を移動する
///
/// ## 引数
/// - `self`: 現在の音程
/// - `semitones`: 移動する半音数（正の値で上昇、負の値で下降）
///
/// ## 戻り値
/// 移動後の音程を表す新しい`Self`インスタンス
///
/// ## 例
/// ```zig
/// const c4 = TwelveEqualTemperament{ .code = .c, .octave = 4 };
/// const e4 = c4.add(4); // C4から4半音上のE4
/// const a3 = c4.add(-3); // C4から3半音下のA3
/// ```
pub fn add(self: Self, semitones: isize) Self {
    // 現在の音程をMIDI番号に変換（C-1 = 0, A4 = 69）
    const self_midi_number: isize = @intCast(12 * (self.octave + 1) + @intFromEnum(self.code));
    
    // 半音数を加算
    const result_midi_number: isize = self_midi_number + semitones;

    // MIDI番号を音名コードとオクターブに分解
    // 12で割った余りが音名、商からオクターブを計算
    const result_code: Code = @enumFromInt(@as(u8, @intCast(@mod(result_midi_number, 12))));
    const result_octave: usize = @intCast(@divTrunc(result_midi_number, 12) - 1);

    return Self{
        .code = result_code,
        .octave = result_octave,
    };
}

/// 音程から周波数（Hz）を計算する
///
/// 十二平均律における周波数計算式を使用します：
/// f = 440 * 2^((n-69)/12)
/// ここで、nはMIDI番号、440HzはA4（MIDI番号69）の基準周波数です。
///
/// ## 引数
/// - `scale`: 周波数を計算する音程
///
/// ## 戻り値
/// 音程の周波数（Hz）
///
/// ## 例
/// ```zig
/// const a4 = TwelveEqualTemperament{ .code = .a, .octave = 4 };
/// const freq = a4.gen(); // 440.0 Hz
/// ```
pub fn gen(scale: Self) f32 {
    // 音程をMIDI番号に変換
    const midi_number: isize = @intCast(12 * (scale.octave + 1) + @intFromEnum(scale.code));
    
    // A4（MIDI番号69、440Hz）からの半音差を計算
    const exp: f32 = @floatFromInt(midi_number - 69);
    
    // 十二平均律の公式: f = 440 * 2^((n-69)/12)
    const result: f32 = 440.0 * std.math.pow(f32, 2.0, exp / 12.0);
    return result;
}

/// 音名コード
///
/// `~s`が付くコードはシャープ（#）を表します。
/// 例：`cs`はC#（ド・シャープ）
///
/// ## 音名とMIDI番号の対応
/// - c (0): ド
/// - cs (1): ド♯
/// - d (2): レ
/// - ds (3): レ♯
/// - e (4): ミ
/// - f (5): ファ
/// - fs (6): ファ♯
/// - g (7): ソ
/// - gs (8): ソ♯
/// - a (9): ラ
/// - as (10): ラ♯
/// - b (11): シ
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
