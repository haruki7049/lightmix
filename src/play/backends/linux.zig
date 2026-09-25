//! # Linux Playback Backend
//!
//! Plays through a sound server when one runs, and directly through ALSA otherwise:
//!
//! 1. The PulseAudio backend, which also reaches PipeWire through `pipewire-pulse`. The server
//!    converts channels and shares the output device with other programs.
//! 2. The ALSA backend, when no server can be reached. It uses a device that no other program
//!    holds.
//!
//! The environment variable `LIGHTMIX_PLAY_BACKEND` chooses one of them: `pulseaudio` or `alsa`.
//! The variables are read from `/proc/self/environ`, so it must be set before the program starts.

const std = @import("std");
const linux = std.os.linux;
const backend = @import("../backend.zig");
const alsa = @import("./alsa.zig");
const pulseaudio = @import("./pulseaudio.zig");
const Buffer = backend.Buffer;
const ChannelRange = backend.ChannelRange;

pub const name = "linux";

/// The backends this one chooses from.
const Choice = enum { automatic, pulseaudio, alsa };

/// Reads `LIGHTMIX_PLAY_BACKEND`.
fn choice(allocator: std.mem.Allocator) Choice {
    var environment = pulseaudio.Environment.load(allocator);
    defer environment.deinit(allocator);
    return parseChoice(environment.get("LIGHTMIX_PLAY_BACKEND"));
}

/// Returns the backend named by `value`; an unset or unknown value chooses automatically.
fn parseChoice(value: ?[]const u8) Choice {
    const text = value orelse return .automatic;
    if (std.mem.eql(u8, text, "pulseaudio")) return .pulseaudio;
    if (std.mem.eql(u8, text, "alsa")) return .alsa;
    return .automatic;
}

/// Plays `buffer` through the PulseAudio server, or through ALSA when no server accepts this
/// client. Once samples were sent to the server, its errors are returned without playing again.
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
    switch (choice(allocator)) {
        .alsa => return alsa.play(allocator, io, buffer),
        .pulseaudio => return pulseaudio.play(allocator, io, buffer),
        .automatic => pulseaudio.play(allocator, io, buffer) catch |err| switch (err) {
            error.ServerUnavailable => return alsa.play(allocator, io, buffer),
            else => return err,
        },
    }
}

/// Returns the channel counts the output accepts: no restriction when a server converts them,
/// else the range of the ALSA device.
pub fn outputChannels(io: std.Io, sample_rate: u32) !?ChannelRange {
    const allocator = std.heap.smp_allocator;
    switch (choice(allocator)) {
        .alsa => return try alsa.outputChannels(io, sample_rate),
        .pulseaudio => return null,
        .automatic => {
            if (pulseaudio.probe(allocator)) return null;
            return try alsa.outputChannels(io, sample_rate);
        },
    }
}

test "parseChoice reads the backend name" {
    try std.testing.expectEqual(Choice.automatic, parseChoice(null));
    try std.testing.expectEqual(Choice.automatic, parseChoice("unknown"));
    try std.testing.expectEqual(Choice.pulseaudio, parseChoice("pulseaudio"));
    try std.testing.expectEqual(Choice.alsa, parseChoice("alsa"));
}
