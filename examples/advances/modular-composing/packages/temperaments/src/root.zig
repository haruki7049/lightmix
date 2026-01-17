//! Temperaments Package
//!
//! このパッケージは音律（音階のチューニングシステム）を提供します。
//! 音律とは、音楽で使用される音程の相対的な周波数関係を定義するシステムです。
//!
//! 現在は十二平均律（Twelve Equal Temperament）のみを提供していますが、
//! 将来的には純正律、ピタゴラス音律などの他の音律も追加できます。

/// 十二平均律（Twelve Equal Temperament）
/// 
/// 1オクターブを12の等しい半音に分割する音律システムです。
/// 西洋音楽で最も一般的に使用されています。
pub const TwelveEqualTemperament = @import("./twelve_equal_temperament.zig");
