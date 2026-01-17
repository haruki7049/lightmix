//! Modular Composing Example
//!
//! このモジュールは、lightmixを使用してモジュラー構成で音声を生成する方法を示します。
//! 独立したパッケージ（temperaments と synths）を組み合わせて、
//! C4（中央のド）のサイン波を生成します。

const std = @import("std");
const lightmix = @import("lightmix");
const synths = @import("synths");

const Wave = lightmix.Wave;

/// 音声波形を生成する関数
///
/// この関数は、C4（中央のド、440Hzの基準でMIDI番号60）の
/// サイン波を1秒間生成します。
///
/// ## 戻り値
/// - `Wave`: 生成された音声波形データ
///
/// ## エラー
/// - メモリ割り当てに失敗した場合にエラーを返します
pub fn gen() !Wave {
    // ページアロケータを使用してメモリを管理
    const allocator = std.heap.page_allocator;
    
    // synths.Sine.gen を呼び出してサイン波を生成
    // 引数:
    //   - allocator: メモリアロケータ
    //   - length: 44100 サンプル（44.1kHzで1秒）
    //   - sample_rate: 44100 Hz（CD品質）
    //   - channels: 1（モノラル）
    //   - scale: C4（中央のド、オクターブ4）
    return synths.Sine.gen(allocator, 44100, 44100, 1, .{ .code = .c, .octave = 4 });
}
