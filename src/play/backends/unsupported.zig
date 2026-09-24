//! # Unsupported Playback Backend
//!
//! Selected for targets without a Pure Zig playback backend. `play` always returns
//! `error.UnsupportedPlatform`, so that `Wave(T).play()` still compiles on every target.

const std = @import("std");
const Buffer = @import("../backend.zig").Buffer;

pub const name = "unsupported";

/// Errors returned by `play`.
pub const Error = error{
    /// The target operating system has no playback backend.
    UnsupportedPlatform,
};

/// Always returns `error.UnsupportedPlatform`.
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) Error!void {
    _ = allocator;
    _ = io;
    _ = buffer;
    return error.UnsupportedPlatform;
}

test "play returns UnsupportedPlatform" {
    const samples = [_]f32{0.0};
    try std.testing.expectError(error.UnsupportedPlatform, play(std.testing.allocator, std.testing.io, .{ .samples = &samples, .sample_rate = 44100, .channels = 1 }));
}
