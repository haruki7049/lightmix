//! Composer

const std = @import("std");
const testing = std.testing;
const Wave = @import("./root.zig").Wave;

const Self = @This();

data: []const Wave,
allocator: std.mem.Allocator,

sample_rate: usize,
channels: usize,
bits: usize,

pub const initOptions = struct {
    sample_rate: usize,
    channels: usize,
    bits: usize,
};

pub fn init(allocator: std.mem.Allocator, options: initOptions) Self {
    return Self{
        .allocator = allocator,
        .data = &[_]Wave{},

        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.data);
}

pub fn init_with(data: []const Wave, allocator: std.mem.Allocator, options: initOptions) Self {
    var list = std.ArrayList(Wave).init(allocator);
    list.appendSlice(data) catch @panic("Out of memory");

    return Self{
        .allocator = allocator,
        .data = list.toOwnedSlice() catch @panic("Out of memory"),

        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
    };
}

pub fn append(self: Self, wave: Wave) !Self {
    var d = std.ArrayList(Wave).init(self.allocator);
    try d.appendSlice(self.data);

    try d.append(wave);

    return Self{
        .allocator = self.allocator,
        .data = try d.toOwnedSlice(),

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    };
}

pub fn appendSlice(self: Self, append_list: []const Wave) !Self {
    var d = std.ArrayList(Wave).init(self.allocator);
    try d.appendSlice(self.data);

    try d.appendSlice(append_list);

    return Self{
        .allocator = self.allocator,
        .data = try d.toOwnedSlice(),

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    };
}

pub fn finalize(self: Self) !Wave {
    var d = std.ArrayList(f32).init(self.allocator);

    for (self.data) |wave| {
        try d.appendSlice(wave.data);
    }

    return Wave{
        .data = try d.toOwnedSlice(),
        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    };
}

test "init & deinit" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();
}

test "init_with & deinit" {
    const allocator = testing.allocator;

    const wave = try Wave.from_file_content(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    const data: []const Wave = &[_]Wave{ wave, wave };

    const composer = Self.init_with(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();
}

test "append" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();

    const wave = try Wave.from_file_content(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    const appended_composer = try composer.append(wave);
    defer appended_composer.deinit();

    try testing.expectEqualSlices(Wave, appended_composer.data, &[_]Wave{ wave });
}

test "appendSlice" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
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

test "finalize" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();

    const generators = Wave.Generators.init(allocator);
    const data: []const f32 = try generators.soundless(44100);
    defer generators.free(data);

    const wave = Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer wave.deinit();

    var append_list = std.ArrayList(Wave).init(allocator);
    defer append_list.deinit();
    try append_list.append(wave);
    try append_list.append(wave);

    const appended_composer = try composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = try appended_composer.finalize();
    defer result.deinit();

    try testing.expectEqual(result.data.len, 88200);

    try testing.expectEqual(result.sample_rate, 44100);
    try testing.expectEqual(result.channels, 1);
    try testing.expectEqual(result.bits, 16);
}
