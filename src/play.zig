//! # lightmix_play - Playback Preview Helper
//!
//! This module provides `play`, a developer preview helper that sends a `lightmix.Wave(T)`
//! to the system audio output. It is published as a separate module (`lightmix_play`) so that
//! the core `lightmix` module stays free of audio backend dependencies.
//!
//! This module does not import `lightmix`. `play` accepts any `Wave(T)` value by duck typing,
//! so it works with the `lightmix` module of any dependency instance.
//!
//! ## Usage
//! ```zig
//! const lightmix_play = @import("lightmix_play");
//!
//! try lightmix_play.play(wave);
//! ```

const std = @import("std");
const zaudio = @import("zaudio");

/// Plays the wave audio through the system audio output.
///
/// Initializes the audio engine, converts samples to f32, and blocks until
/// playback completes. The wave is only read; its ownership stays with the caller.
///
/// ## Parameters
/// - `wave`: A `lightmix.Wave(T)` value, where `T` is a floating-point sample type
///
/// ## Errors
/// Returns errors from the audio engine initialization or playback
pub fn play(wave: anytype) anyerror!void {
    comptime assertWave(@TypeOf(wave));

    if (wave.samples.len == 0) return;
    const allocator = wave.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    zaudio.init(allocator);
    defer zaudio.deinit();

    var engine: *zaudio.Engine = try zaudio.Engine.create(null);
    defer engine.destroy();

    const samples = try allocator.alloc(f32, wave.samples.len);
    defer allocator.free(samples);

    for (wave.samples, 0..) |orig_sample, i| {
        samples[i] = @as(f32, @floatCast(orig_sample));
    }

    var buffer_config = zaudio.AudioBuffer.Config.init(.float32, wave.channels, samples.len / wave.channels, samples.ptr);
    buffer_config.sample_rate = wave.sample_rate;
    const buffer = try zaudio.AudioBuffer.create(buffer_config);
    defer buffer.destroy();
    const sound = try engine.createSoundFromDataSource(buffer.asDataSourceMut(), .{}, null);
    defer sound.destroy();

    try sound.start();

    while (!sound.isAtEnd()) {
        try io.sleep(std.Io.Duration.fromNanoseconds(10 * std.time.ns_per_ms), .real);
    }
}

/// Checks at compile time that `W` has the fields `play` reads from a `lightmix.Wave(T)`.
fn assertWave(comptime W: type) void {
    const fields = .{ "samples", "allocator", "sample_rate", "channels" };
    inline for (fields) |name| {
        if (!@hasField(W, name)) @compileError("lightmix_play.play expects a lightmix.Wave(T), found " ++ @typeName(W));
    }
    const Sample = @typeInfo(@FieldType(W, "samples")).pointer.child;
    if (@typeInfo(Sample) != .float) @compileError("lightmix_play.play expects floating-point samples, found " ++ @typeName(Sample));
}

test "play returns immediately for an empty wave" {
    const Fake = struct {
        samples: []const f64,
        allocator: std.mem.Allocator,
        sample_rate: u32,
        channels: u16,
    };
    try play(Fake{ .samples = &.{}, .allocator = std.testing.allocator, .sample_rate = 44100, .channels = 1 });
}
