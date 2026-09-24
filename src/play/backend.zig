//! # Playback Backend Interface
//!
//! A playback backend is a namespace (a Zig file) that sends a `Buffer` to an audio output.
//! Each backend must declare:
//!
//! - `pub const name: []const u8`: A short name of the backend (e.g. `"zaudio"`).
//! - `pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void`:
//!   Plays `buffer` and blocks until playback completes. The buffer is only read; its
//!   ownership stays with the caller.
//!
//! `Selected` is the backend chosen for the target operating system at compile time.

const std = @import("std");
const builtin = @import("builtin");

/// Interleaved 32-bit floating-point samples handed to a backend.
///
/// Every backend receives this format, whatever the sample type `T` of the source
/// `Wave(T)` is. Samples are not clamped, so values outside `[-1.0, 1.0]` reach the backend as-is.
pub const Buffer = struct {
    /// Interleaved samples. The length is a multiple of `channels`.
    samples: []const f32,

    /// Sample rate in Hz.
    sample_rate: u32,

    /// Number of interleaved channels.
    channels: u16,

    /// Returns the number of frames (samples per channel).
    pub fn frames(self: Buffer) usize {
        return self.samples.len / self.channels;
    }
};

/// The backend selected for the target operating system.
pub const Selected = select(builtin.os.tag);

/// Returns the backend for `os_tag`.
fn select(comptime os_tag: std.Target.Os.Tag) type {
    const Backend = switch (os_tag) {
        .macos => @import("./backends/coreaudio.zig"),
        // The other targets use zaudio until the Pure Zig backends replace it (#296).
        else => @import("./backends/zaudio.zig"),
    };
    comptime assertBackend(Backend);
    return Backend;
}

/// Checks at compile time that `Backend` declares `name` and `play` as described in the module docs.
pub fn assertBackend(comptime Backend: type) void {
    if (!@hasDecl(Backend, "name")) @compileError("playback backend " ++ @typeName(Backend) ++ " must declare `pub const name: []const u8`");
    if (!@hasDecl(Backend, "play")) @compileError("playback backend " ++ @typeName(Backend) ++ " must declare `pub fn play`");

    const info = @typeInfo(@TypeOf(Backend.play)).@"fn";
    const expected = [_]type{ std.mem.Allocator, std.Io, Buffer };
    if (info.params.len != expected.len) @compileError("`" ++ @typeName(Backend) ++ ".play` must take (std.mem.Allocator, std.Io, Buffer)");
    inline for (info.params, expected) |param, Expected| {
        if (param.type != Expected) @compileError("`" ++ @typeName(Backend) ++ ".play` must take (std.mem.Allocator, std.Io, Buffer)");
    }

    const Return = info.return_type orelse @compileError("`" ++ @typeName(Backend) ++ ".play` must not be generic");
    const return_info = @typeInfo(Return);
    if (return_info != .error_union or return_info.error_union.payload != void) @compileError("`" ++ @typeName(Backend) ++ ".play` must return `!void`");
}

test "Buffer.frames divides the sample count by the channel count" {
    const samples = [_]f32{ 0.0, 0.1, 0.2, 0.3, 0.4, 0.5 };
    const buffer: Buffer = .{ .samples = &samples, .sample_rate = 44100, .channels = 2 };
    try std.testing.expectEqual(@as(usize, 3), buffer.frames());
}

test "assertBackend accepts a backend that matches the interface" {
    const Fake = struct {
        pub const name = "fake";
        pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
            _ = allocator;
            _ = io;
            _ = buffer;
        }
    };
    comptime assertBackend(Fake);
    comptime assertBackend(Selected);
}

test "Import tests" {
    _ = Selected;
}
