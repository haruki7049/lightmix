pub const Wave = @import("./wave.zig").inner;
pub const Composer = @import("./composer.zig").inner;

test "Import tests" {
    _ = @import("./wave.zig");
    _ = @import("./composer.zig");
}
