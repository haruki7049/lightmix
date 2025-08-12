//! Generators

const std = @import("std");
const testing = std.testing;

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{ .allocator = allocator };
}

pub fn soundless(self: Self, samples: usize) ![]const f32 {
    var result = std.ArrayList(f32).init(self.allocator);
    var i: usize = 0;

    while (i < samples) : (i += 1) {
        result.append(0.0) catch |err| {
            std.debug.print("{any}\n", .{err});
            @panic("Panic in Wave.Generators.soundless");
        };
    }

    return try result.toOwnedSlice();
}

pub fn free(self: Self, data: []const f32) void {
    self.allocator.free(data);
}
