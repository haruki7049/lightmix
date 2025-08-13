//! Composer

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

pub fn append(self: Self, wave: Wave) !Self {
    var d = std.ArrayList(Wave).init(self.allocator);
    try d.appendSlice(self.data);

    try d.append(wave);

    return Self{
        .allocator = self.allocator,
        .data = try d.toOwnedSlice(),
    };
}

pub fn appendSlice(self: Self, append_list: []const Wave) !Self {
    var d = std.ArrayList(Wave).init(self.allocator);
    try d.appendSlice(self.data);

    try d.appendSlice(append_list);

    return Self{
        .allocator = self.allocator,
        .data = try d.toOwnedSlice(),
    };
}

test "init & deinit" {
    const allocator = testing.allocator;
    const composer = try Self.init(allocator);
    defer composer.deinit();
}

test "append" {
    const allocator = testing.allocator;
    const composer = try Self.init(allocator);
    defer composer.deinit();

    const wave = try Wave.from_file_content(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    const appended_composer = try composer.append(wave);
    defer appended_composer.deinit();

    try testing.expectEqualSlices(Wave, appended_composer.data, &[_]Wave{ wave });
}

test "appendSlice" {
    const allocator = testing.allocator;
    const composer = try Self.init(allocator);
    defer composer.deinit();

    const wave = try Wave.from_file_content(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    var append_list = std.ArrayList(Wave).init(allocator);
    defer append_list.deinit();
    try append_list.append(wave);
    try append_list.append(wave);

    const appended_composer = try composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    try testing.expectEqualSlices(Wave, appended_composer.data, &[_]Wave{ wave, wave });
}
