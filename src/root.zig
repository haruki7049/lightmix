//! # lightmix - Audio Synthesis and Manipulation Library
//!
//! lightmix is a Zig library for audio waveform generation, manipulation, and composition.
//! It provides type-safe, generic interfaces for working with audio data.
//!
//! ## Core Types
//!
//! ### Wave
//! The `Wave` type function creates audio waveform types for different sample formats.
//! It supports operations like mixing, filtering, and reading/writing WAV files.
//!
//! ### Composer
//! The `Composer` type function creates types for sequencing and overlaying multiple
//! Wave instances in time to create complex audio arrangements.
//!
//! ## Example Usage
//!
//! ```zig
//! const std = @import("std");
//! const lightmix = @import("lightmix");
//!
//! pub fn main() !void {
//!     const allocator = std.heap.page_allocator;
//!
//!     // Create a simple sine wave
//!     const Wave = lightmix.Wave;
//!     var samples: [44100]f64 = undefined;
//!     for (0..samples.len) |i| {
//!         const t = @as(f64, @floatFromInt(i)) / 44100.0;
//!         samples[i] = @sin(t * 440.0 * 2.0 * std.math.pi);
//!     }
//!
//!     const wave = Wave(f64).init(&samples, allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer wave.deinit();
//!
//!     // Create a composition with multiple waves
//!     const Composer = lightmix.Composer;
//!     const composer = Composer(f64).init(allocator, .{
//!         .sample_rate = 44100,
//!         .channels = 1,
//!     });
//!     defer composer.deinit();
//!
//!     const arranged = composer.append(.{ .wave = wave, .start_point = 0 });
//!     defer arranged.deinit();
//!
//!     const result = arranged.finalize(.{});
//!     defer result.deinit();
//! }
//! ```

pub const Wave = @import("./wave.zig").inner;
pub const Composer = @import("./composer.zig").inner;

test "Import tests" {
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
}
