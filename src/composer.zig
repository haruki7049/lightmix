const std = @import("std");
const testing = std.testing;
const Wave = @import("./root.zig").Wave;

const Self = @This();

data: []const Wave,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    var d = std.ArrayList(Wave).init(allocator);

    return Self{
        .allocator = allocator,
        .data = try d.toOwnedSlice(),
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.data);
}

test "init & deinit" {
    const allocator = testing.allocator;
    const composer = try Self.init(allocator);
    defer composer.deinit();
}
