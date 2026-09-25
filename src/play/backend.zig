//! # Playback Backend Interface
//!
//! A playback backend is a namespace (a Zig file) that sends a `Buffer` to an audio output.
//! Each backend must declare:
//!
//! - `pub const name: []const u8`: A short name of the backend (e.g. `"alsa"`).
//! - `pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void`:
//!   Plays `buffer` and blocks until playback completes. The buffer is only read; its
//!   ownership stays with the caller.
//!
//! A backend may also declare:
//!
//! - `pub fn outputChannels(io: std.Io, sample_rate: u32) !ChannelRange` (or `!?ChannelRange`):
//!   Returns the channel counts accepted by the output device `play` would use for `sample_rate`.
//!   A backend whose system converts channels itself omits it, and `outputChannels` returns null.
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

/// The inclusive range of channel counts an output device accepts.
pub const ChannelRange = struct {
    /// Smallest accepted channel count.
    min: u16,

    /// Largest accepted channel count.
    max: u16,

    /// Returns the accepted channel count closest to `channels`.
    pub fn clamp(self: ChannelRange, channels: u16) u16 {
        return std.math.clamp(channels, self.min, self.max);
    }
};

/// The backend selected for the target operating system.
pub const Selected = select(builtin.os.tag);

/// Returns the backend for `os_tag`.
fn select(comptime os_tag: std.Target.Os.Tag) type {
    const Backend = switch (os_tag) {
        .linux => @import("./backends/linux.zig"),
        .macos => @import("./backends/coreaudio.zig"),
        .windows => @import("./backends/winmm.zig"),
        else => @import("./backends/unsupported.zig"),
    };
    comptime assertBackend(Backend);
    return Backend;
}

/// Returns the channel counts accepted by the output device for `sample_rate`, or null when the
/// selected backend does not restrict them.
pub fn outputChannels(io: std.Io, sample_rate: u32) !?ChannelRange {
    if (!@hasDecl(Selected, "outputChannels")) return null;
    return try Selected.outputChannels(io, sample_rate);
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

    if (@hasDecl(Backend, "outputChannels")) {
        const channels_info = @typeInfo(@TypeOf(Backend.outputChannels)).@"fn";
        if (channels_info.params.len != 2 or channels_info.params[0].type != std.Io or channels_info.params[1].type != u32) {
            @compileError("`" ++ @typeName(Backend) ++ ".outputChannels` must take (std.Io, u32)");
        }
        const channels_return = @typeInfo(channels_info.return_type orelse @compileError("`" ++ @typeName(Backend) ++ ".outputChannels` must not be generic"));
        if (channels_return != .error_union or (channels_return.error_union.payload != ChannelRange and channels_return.error_union.payload != ?ChannelRange)) {
            @compileError("`" ++ @typeName(Backend) ++ ".outputChannels` must return `!ChannelRange` or `!?ChannelRange`");
        }
    }
}

test "Buffer.frames divides the sample count by the channel count" {
    const samples = [_]f32{ 0.0, 0.1, 0.2, 0.3, 0.4, 0.5 };
    const buffer: Buffer = .{ .samples = &samples, .sample_rate = 44100, .channels = 2 };
    try std.testing.expectEqual(@as(usize, 3), buffer.frames());
}

test "ChannelRange.clamp returns the closest accepted channel count" {
    const range: ChannelRange = .{ .min = 2, .max = 8 };
    try std.testing.expectEqual(@as(u16, 2), range.clamp(1));
    try std.testing.expectEqual(@as(u16, 2), range.clamp(2));
    try std.testing.expectEqual(@as(u16, 5), range.clamp(5));
    try std.testing.expectEqual(@as(u16, 8), range.clamp(12));
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
    _ = @import("./backends/unsupported.zig");
    if (builtin.os.tag == .linux) {
        _ = @import("./backends/alsa.zig");
        _ = @import("./backends/pulseaudio.zig");
        _ = @import("./backends/linux.zig");
    }
}
