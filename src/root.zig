//! # lightmix - Audio Synthesis and Manipulation Library
//!
//! lightmix is a Zig library for audio waveform generation, manipulation, and composition.
//! It provides type-safe, generic interfaces for working with audio data.
//!
//! ## Core Types
//!
//! ### Wave
//! The `Wave` type function creates audio waveform types for the sample types `f32`, `f64`,
//! `f80` and `f128`. A `Wave(T)` supports:
//!
//! - Mixing (`mix`), splitting (`separate`), padding and truncating (`fill_zero_to_end`) and
//!   copying (`clone`).
//! - Channel conversion (`to_mono`, `to_stereo` and `to_channels`, which also takes a gain matrix).
//! - Reading and writing WAV files (`read`, `write` and `size`).
//! - Playback for previewing (`play` and `playWithOptions`), a developer helper that adapts
//!   channels to the output device by default.
//!
//! ### Composer
//! The `Composer` type function creates types for sequencing and overlaying multiple
//! Wave instances in time to create complex audio arrangements. It renders the whole
//! composition at once (`finalize`) or in blocks (`render_stream`).
//!
//! ## Playback Helpers
//!
//! `ChannelRange` and `outputChannels` describe the channel counts that the output device
//! used by `Wave(T).play` accepts.
//!
//! ## Build System
//!
//! `build.zig` of this package provides `addWave` and `installWave` to generate and install
//! WAV files while building, `addPlay` and `installPlay` to play them, and `currentTimestamp`
//! for the `PEAK` chunk. See the README for their usage.
//!
//! ## Example Usage
//!
//! ```zig
//! const std = @import("std");
//! const lightmix = @import("lightmix");
//! const Wave = lightmix.Wave;
//! const Composer = lightmix.Composer;
//!
//! pub fn main() !void {
//!     const allocator = std.heap.page_allocator;
//!
//!     // Create a simple sine wave
//!     var samples: [44100]f64 = undefined;
//!     for (0..samples.len) |i| {
//!         const t = @as(f64, @floatFromInt(i)) / 44100.0;
//!         samples[i] = @sin(t * 440.0 * 2.0 * std.math.pi);
//!     }
//!
//!     // Wave(T).init() creates a deep copy of samples
//!     const wave: Wave(f64) = try Wave(f64).init(&samples, allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer wave.deinit();
//!
//!     // Create a composition with multiple waves
//!     var composer: Composer(f64) = try Composer(f64).init(allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer composer.deinit();
//!
//!     // Composer(T).append() modifies the Composer in-place
//!     try composer.append(.{ .wave = wave, .start_point = 0 });
//!
//!     const result: Wave(f64) = try composer.finalize(.{});
//!     defer result.deinit();
//! }
//! ```

const std = @import("std");

pub const Wave = @import("./wave.zig").inner;
pub const Composer = @import("./composer.zig").inner;

/// The inclusive range of channel counts an output device accepts.
pub const ChannelRange = @import("./play/backend.zig").ChannelRange;

/// Returns the channel counts accepted by the output device that `Wave(T).play()` would use for
/// a wave of `sample_rate`, or null when the playback backend converts channels itself and does
/// not restrict them: a PulseAudio or PipeWire server, CoreAudio and WinMM.
///
/// Use it to choose a channel layout yourself, e.g. `wave.to_channels(range.clamp(wave.channels), .{})`,
/// before `playWithOptions(.{ .channels = .strict })`.
///
/// ## Errors
/// Returns the errors of the playback backend, e.g. when no output device is found or every
/// device is held by a sound server.
pub fn outputChannels(sample_rate: u32) anyerror!?ChannelRange {
    var threaded = std.Io.Threaded.init(std.heap.smp_allocator, .{});
    defer threaded.deinit();
    return try @import("./play/backend.zig").outputChannels(threaded.io(), sample_rate);
}

test "Import tests" {
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
    _ = @import("./play/backend.zig");
}
