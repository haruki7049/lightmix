//! # lightmix
//!
//! `lightmix` is an audio processing library written by Zig-lang.

pub const Synth = @import("./synth.zig");
pub const Wave = @import("./wave.zig");
pub const Composer = @import("./composer.zig");

test "Import tests" {
    _ = @import("./synth.zig");
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
}
