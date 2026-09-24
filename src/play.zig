//! # lightmix_play - Playback Preview Helper
//!
//! This module provides `play`, a developer preview helper that sends a `lightmix.Wave(T)`
//! to the system audio output. It is published as a separate module (`lightmix_play`) so that
//! the core `lightmix` module stays free of audio backend dependencies.
//!
//! This module does not import `lightmix`. `play` accepts any `Wave(T)` value by duck typing,
//! so it works with the `lightmix` module of any dependency instance.
//!
//! `play` converts the wave into a `backend.Buffer` and hands it to the backend selected for
//! the target operating system (`backend.Selected`). See `backend` for the backend interface.
//!
//! ## Usage
//! ```zig
//! const lightmix_play = @import("lightmix_play");
//!
//! try lightmix_play.play(wave);
//! ```

const std = @import("std");

/// The playback backend interface and the backend selected for the target.
pub const backend = @import("./play/backend.zig");

/// Plays the wave audio through the system audio output.
///
/// Converts samples to f32 and blocks until playback completes. The wave is only read;
/// its ownership stays with the caller.
///
/// ## Parameters
/// - `wave`: A `lightmix.Wave(T)` value, where `T` is a floating-point sample type
///
/// ## Errors
/// Returns errors from the conversion buffer allocation and from the playback backend
pub fn play(wave: anytype) anyerror!void {
    comptime assertWave(@TypeOf(wave));

    if (wave.samples.len == 0) return;
    const allocator = wave.allocator;
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const samples = try toF32(allocator, wave.samples);
    defer allocator.free(samples);

    try backend.Selected.play(allocator, io, .{
        .samples = samples,
        .sample_rate = wave.sample_rate,
        .channels = wave.channels,
    });
}

/// Converts `samples` to f32. The caller owns the returned slice and frees it with `allocator`.
fn toF32(allocator: std.mem.Allocator, samples: anytype) std.mem.Allocator.Error![]f32 {
    const result = try allocator.alloc(f32, samples.len);
    for (samples, result) |sample, *dest| {
        dest.* = @floatCast(sample);
    }
    return result;
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

test "toF32 converts every sample without clamping" {
    const allocator = std.testing.allocator;
    inline for (.{ f64, f80, f128 }) |T| {
        const samples = [_]T{ 0.0, 0.5, -0.25, 1.5 };
        const result = try toF32(allocator, @as([]const T, &samples));
        defer allocator.free(result);
        try std.testing.expectEqualSlices(f32, &.{ 0.0, 0.5, -0.25, 1.5 }, result);
    }
}

test "Import tests" {
    _ = backend;
}
