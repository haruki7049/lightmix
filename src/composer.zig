//! # Composer
//!
//! Composer is used to combine multipul `Wave`.

const std = @import("std");
const lightmix_wav = @import("lightmix_wav");
const testing = std.testing;
const Wave = @import("./root.zig").Wave;

const Self = @This();

pub const WaveInfo = struct {
    wave: Wave,
    start_point: usize,

    fn to_wave(self: WaveInfo, allocator: std.mem.Allocator) Wave {
        var padding_data: []f32 = allocator.alloc(f32, self.start_point) catch @panic("Out of memory");

        for (0..padding_data.len) |i| {
            padding_data[i] = 0.0;
        }

        const slices: []const []const f32 = &[_][]const f32{ padding_data, self.wave.data };
        const data = std.mem.concat(allocator, f32, slices);

        const result: Wave = Wave.init(data, allocator, .{
            .sample_rate = self.wave.sample_rate,
            .channels = self.wave.channels,
        });

        return result;
    }
};

info: []const WaveInfo,
allocator: std.mem.Allocator,

sample_rate: usize,
channels: usize,

pub const Options = struct {
    sample_rate: usize,
    channels: usize,
};

pub fn init(
    allocator: std.mem.Allocator,
    options: Options,
) Self {
    return Self{
        .allocator = allocator,
        .info = &[_]WaveInfo{},

        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.info);
}

pub fn init_with(
    info: []const WaveInfo,
    allocator: std.mem.Allocator,
    options: Options,
) Self {
    var list: std.array_list.Aligned(WaveInfo, null) = .empty;
    list.appendSlice(allocator, info) catch @panic("Out of memory");

    return Self{
        .allocator = allocator,
        .info = list.toOwnedSlice(allocator) catch @panic("Out of memory"),

        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

pub fn append(self: Self, waveinfo: WaveInfo) Self {
    var d: std.array_list.Aligned(WaveInfo, null) = .empty;
    d.appendSlice(self.allocator, self.info) catch @panic("Out of memory");
    d.append(self.allocator, waveinfo) catch @panic("Out of memory");

    const result: []const WaveInfo = d.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .allocator = self.allocator,
        .info = result,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

pub fn appendSlice(self: Self, append_list: []const WaveInfo) Self {
    var d: std.array_list.Aligned(WaveInfo, null) = .empty;
    d.appendSlice(self.allocator, self.info) catch @panic("Out of memory");
    d.appendSlice(self.allocator, append_list) catch @panic("Out of memory");

    const result: []const WaveInfo = d.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .allocator = self.allocator,
        .info = result,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

pub fn finalize(self: Self) Wave {
    var end_point: usize = 0;

    // Calculate the length for emitted wave
    for (self.info) |waveinfo| {
        const ep = waveinfo.start_point + waveinfo.wave.data.len;

        if (end_point < ep)
            end_point = ep;
    }

    var padded_waveinfo_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer padded_waveinfo_list.deinit(self.allocator);

    // Filter each WaveInfo to append padding both of start and last
    for (self.info) |waveinfo| {
        const padded_at_start: []const f32 = padding_for_start(waveinfo.wave.data, waveinfo.start_point, self.allocator);
        defer self.allocator.free(padded_at_start);

        const padded_at_start_and_last: []const f32 = padding_for_last(padded_at_start, end_point, self.allocator);
        defer self.allocator.free(padded_at_start_and_last);

        const wave: Wave = Wave.init(padded_at_start_and_last, self.allocator, .{
            .sample_rate = self.sample_rate,
            .channels = self.channels,
        });

        const wi: WaveInfo = WaveInfo{
            .wave = wave,
            .start_point = waveinfo.start_point,
        };

        padded_waveinfo_list.append(self.allocator, wi) catch @panic("Out of memory");
    }

    const padded_waveinfo_slice: []const WaveInfo = padded_waveinfo_list.toOwnedSlice(self.allocator) catch @panic("Out of memory");
    defer self.allocator.free(padded_waveinfo_slice);

    const empty_data: []const f32 = generate_soundless_data(end_point, self.allocator);
    defer self.allocator.free(empty_data);

    var result: Wave = Wave.init(empty_data, self.allocator, .{
        .sample_rate = self.sample_rate,
        .channels = self.channels,
    });

    for (padded_waveinfo_slice) |waveinfo| {
        const wave = result.mix(waveinfo.wave);
        result.deinit();
        waveinfo.wave.deinit();
        result = wave;
    }

    return result;
}

fn padding_for_start(data: []const f32, start_point: usize, allocator: std.mem.Allocator) []const f32 {
    const padding_length: usize = start_point;
    var padding: std.array_list.Aligned(f32, null) = .empty;
    defer padding.deinit(allocator);

    // Append padding
    for (0..padding_length) |_|
        padding.append(allocator, 0.0) catch @panic("Out of memory");

    // Append data slice
    padding.appendSlice(allocator, data) catch @panic("Out of memory");

    const result: []const f32 = padding.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

fn padding_for_last(data: []const f32, end_point: usize, allocator: std.mem.Allocator) []const f32 {
    std.debug.assert(data.len <= end_point);

    const padding_length: usize = end_point - data.len;
    var padding: std.array_list.Aligned(f32, null) = .empty;
    defer padding.deinit(allocator);

    // Append data slice
    padding.appendSlice(allocator, data) catch @panic("Out of memory");

    // Append padding
    for (0..padding_length) |_|
        padding.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f32 = padding.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) []const f32 {
    var list: std.array_list.Aligned(f32, null) = .empty;
    defer list.deinit(allocator);

    // Append empty wave
    for (0..length) |_|
        list.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f32 = list.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

test "padding_for_start" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{ 1.0, 1.0 };
    const start_point: usize = 10;

    const result: []const f32 = padding_for_start(data, start_point, allocator);
    defer allocator.free(result);

    try testing.expectEqual(data.len + start_point, result.len);

    const expected: []const f32 = &[_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0 };
    for (0..result.len) |i| {
        try testing.expectApproxEqAbs(expected[i], result[i], 0.001);
    }
}

test "init & deinit" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();
}

test "init_with & deinit" {
    const allocator = testing.allocator;

    const wave = Wave.from_file_content(.i16, @embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    const info: []const WaveInfo = &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } };

    const composer = Self.init_with(info, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();
}

test "append" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    const wave = Wave.from_file_content(.i16, @embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    const appended_composer = composer.append(.{ .wave = wave, .start_point = 0 });
    defer appended_composer.deinit();

    try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{.{ .wave = wave, .start_point = 0 }});
}

test "appendSlice" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    const wave = Wave.from_file_content(.i16, @embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer append_list.deinit(allocator);
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });

    const appended_composer = composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } });
}

test "finalize" {
    const allocator = testing.allocator;
    const composer = Self.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var data: []f32 = try allocator.alloc(f32, 44100);
    defer allocator.free(data);

    for (0..data.len) |i| {
        data[i] = 1.0;
    }

    const wave = Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer append_list.deinit(allocator);
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
    try append_list.append(allocator, .{ .wave = wave, .start_point = 44100 });

    const appended_composer = composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = appended_composer.finalize();
    defer result.deinit();

    try testing.expectEqual(result.data.len, 88200);

    try testing.expectEqual(result.sample_rate, 44100);
    try testing.expectEqual(result.channels, 1);
}
