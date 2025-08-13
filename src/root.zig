//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
pub const Wave = @import("./wave.zig");
pub const Composer = @import("./composer.zig");

test "Import tests" {
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
}
