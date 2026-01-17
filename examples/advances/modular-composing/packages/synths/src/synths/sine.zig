//! Sine Wave Synthesizer (サイン波シンセサイザー)
//!
//! このモジュールは、純粋なサイン波を生成するシンセサイザーを実装しています。
//! サイン波は最も基本的な波形で、単一の周波数成分のみを持つ純音です。
//!
//! ## 特徴
//! - 倍音を含まない純粋な音色
//! - 音叉や正弦波オシレーターと同じ音色
//! - 音響学やシンセサイザーの基本となる波形

const std = @import("std");
const lightmix = @import("lightmix");
const temperaments = @import("temperaments");

const Wave = lightmix.Wave;
const Scale = temperaments.TwelveEqualTemperament;

/// 指定された音程でサイン波を生成する
///
/// この関数は、与えられた音程（音階）に基づいてサイン波の音声データを生成します。
/// 生成される波形は y = sin(2πft) の形式で、fは音程から計算される周波数です。
///
/// ## 引数
/// - `allocator`: メモリアロケータ（生成されたサンプルデータの管理に使用）
/// - `length`: 生成するサンプル数（例：44100サンプルで1秒@44.1kHz）
/// - `sample_rate`: サンプリングレート（Hz）。一般的な値は44100（CD品質）または48000
/// - `channels`: チャンネル数（1=モノラル、2=ステレオ）
/// - `scale`: 音程（音名とオクターブを含む）
///
/// ## 戻り値
/// - `Wave`: 生成されたサイン波の音声データを含むWaveオブジェクト
///
/// ## エラー
/// - メモリ割り当てに失敗した場合にエラーを返します
///
/// ## 例
/// ```zig
/// const allocator = std.heap.page_allocator;
/// const scale = Scale{ .code = .a, .octave = 4 }; // A4（440Hz）
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
    // 指定された長さ分のサンプルデータを割り当て
    var samples = try allocator.alloc(f32, length);

    // 各サンプルポイントでサイン波の値を計算
    for (0..samples.len) |i| {
        // 時間 t を計算（秒単位）
        // t = サンプルインデックス / サンプリングレート
        const t = @as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(sample_rate));
        
        // サイン波の計算: sin(2πft)
        // scale.gen() で周波数fを取得
        // 2πft はラジアン単位の位相
        samples[i] = @sin(t * scale.gen() * 2.0 * std.math.pi);
    }

    // Waveオブジェクトを初期化して返す
    return Wave.init(samples, allocator, .{
        .sample_rate = sample_rate,
        .channels = channels,
    });
}
