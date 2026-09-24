//! # zaudio Playback Backend
//!
//! Plays a `Buffer` through `zaudio` (`miniaudio`). This backend is temporary: it is
//! replaced by the Pure Zig backends and removed in #296.

const std = @import("std");
const zaudio = @import("zaudio");
const Buffer = @import("../backend.zig").Buffer;

pub const name = "zaudio";

/// Plays `buffer` through the default output device and blocks until playback completes.
///
/// ## Errors
/// Returns errors from the audio engine initialization or playback
pub fn play(allocator: std.mem.Allocator, io: std.Io, buffer: Buffer) !void {
    zaudio.init(allocator);
    defer zaudio.deinit();

    var engine: *zaudio.Engine = try zaudio.Engine.create(null);
    defer engine.destroy();

    var buffer_config = zaudio.AudioBuffer.Config.init(.float32, buffer.channels, buffer.frames(), buffer.samples.ptr);
    buffer_config.sample_rate = buffer.sample_rate;
    const audio_buffer = try zaudio.AudioBuffer.create(buffer_config);
    defer audio_buffer.destroy();
    const sound = try engine.createSoundFromDataSource(audio_buffer.asDataSourceMut(), .{}, null);
    defer sound.destroy();

    try sound.start();

    while (!sound.isAtEnd()) {
        try io.sleep(std.Io.Duration.fromNanoseconds(10 * std.time.ns_per_ms), .real);
    }
}
