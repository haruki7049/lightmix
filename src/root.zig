//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const zig_wav = @import("zig_wav");
const testing = std.testing;

pub const Wave = @import("./wave.zig");
pub const Composer = @import("./composer.zig");

test "Import tests" {
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
}
