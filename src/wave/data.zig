const std = @import("std");

const Self = @This();

inner: []const []const f32,
allocator: std.mem.Allocator,

pub fn init(inner: []const []const f32, allocator: std.mem.Allocator) Data {
    return Data{ .inner = inner, .allocator = allocator };
}

pub fn deinit(self: Data) void {
    for (self.inner) |d|
        self.allocator.free(d);

    self.allocator.free(self.inner);
}

pub fn len(self: Self) usize {
    const length: usize = self.inner[0].len;

    for (self.inner) |inner|
        std.debug.assert(length, inner.len);

    return length;
}

pub fn to_wavedata(self: Data) []const f32 {
    var result = std.ArrayList(f32).init(self.allocator);
    const channels: usize = self.inner.len;

    for (0..channels) |ch| {
        for (self.inner) |d| {
            result.append(d[ch]) catch @panic("Out of memory");
        }
    }

    return result.toOwnedSlice() catch @panic("Out of memory");
}

test "to_wavedata" {
    const allocator = testing.allocator;

    const inner: []const []const f32 = &[_][]const f32{ &[_]f32{ 0.0, 0.0 }, &[_]f32{ 1.0, 1.0 } };
    const data: Data = Data.init(inner, allocator);
    const result: []const f32 = data.to_wavedata();
    defer allocator.free(result);

    try testing.expectEqualSlices(f32, result, &[_]f32{ 0.0, 1.0, 0.0, 1.0 });
}

pub fn from_wavedata(data: []const f32, channels: usize, allocator: std.mem.Allocator) Data {
    var result = std.ArrayList([]const f32).init(allocator);

    for (0..channels) |channel| {
        std.debug.print("channel: {d}\n", .{channel});

        var list = std.ArrayList(f32).init(allocator);

        for (data, 0..) |sample, i| {
            if (i % channels == channel) {
                std.debug.print("i: {d}, sample: {d}\n", .{i, sample});
                list.append(sample) catch @panic("Out of memory");
            }
        }

        const l: []const f32 = list.toOwnedSlice() catch @panic("Out of memory");
        std.debug.print("l: {any}\n", .{l});

        result.append(l) catch @panic("Out of memory");
    }

    const d = Data{
        .inner = result.toOwnedSlice() catch @panic("Out of memory"),
        .allocator = allocator,
    };

    return d;
}

test "from_wavedata" {
    const allocator = testing.allocator;

    const wavedata: []const f32 = &[_]f32{ 0.0, 1.0, 0.0, 1.0 };
    const channels: usize = 2;
    const result: Data = Data.from_wavedata(wavedata, channels, allocator);
    defer result.deinit();

    const expected: []const []const f32 = &[_][]const f32{ &[_]f32{ 0.0, 0.0 }, &[_]f32{ 1.0, 1.0 } };

    for (0..expected.len) |i|
        try testing.expectEqualSlices(f32, expected[i], result.inner[i]);
}
