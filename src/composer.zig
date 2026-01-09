const std = @import("std");
const lightmix_wav = @import("lightmix_wav");
const testing = std.testing;
const Wave = @import("./root.zig").Wave;

const Self = @This();

pub const WaveInfo = struct {
    wave: Wave,
    start_point: usize,

    fn to_wave(self: WaveInfo, allocator: std.mem.Allocator) Wave {
        var padding_samples: []f128 = allocator.alloc(f128, self.start_point) catch @panic("Out of memory");

        for (0..padding_samples.len) |i| {
            padding_samples[i] = 0.0;
        }

        const slices: []const []const f128 = &[_][]const f128{ padding_samples, self.wave.samples };
        const samples = std.mem.concat(allocator, f128, slices);

        const result: Wave = Wave.init(samples, allocator, .{
            .sample_rate = self.wave.sample_rate,
            .channels = self.wave.channels,
        });

        return result;
    }
};

info: []const WaveInfo,
allocator: std.mem.Allocator,
sample_rate: u32,
channels: u16,

pub const initOptions = struct {
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
};

pub const initWithOptions = struct {
    info: []const WaveInfo,
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
};

pub fn init(
    options: initOptions,
) Self {
    return Self{
        .info = &[_]WaveInfo{},
        .allocator = options.allocator,
        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

pub fn deinit(self: Self) void {
    self.allocator.free(self.info);
}

pub fn init_with(
    options: initWithOptions,
) Self {
    var list: std.array_list.Aligned(WaveInfo, null) = .empty;
    list.appendSlice(options.allocator, options.info) catch @panic("Out of memory");

    return Self{
        .info = list.toOwnedSlice(options.allocator) catch @panic("Out of memory"),
        .allocator = options.allocator,
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

pub fn finalize(self: Self, options: Wave.mixOptions) Wave {
    var end_point: usize = 0;

    // Calculate the length for emitted wave
    for (self.info) |waveinfo| {
        const ep = waveinfo.start_point + waveinfo.wave.samples.len;

        if (end_point < ep)
            end_point = ep;
    }

    var padded_waveinfo_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer padded_waveinfo_list.deinit(self.allocator);

    // Filter each WaveInfo to append padding both of start and last
    for (self.info) |waveinfo| {
        const padded_at_start: []const f128 = padding_for_start(waveinfo.wave.samples, waveinfo.start_point, self.allocator);
        defer self.allocator.free(padded_at_start);

        const padded_at_start_and_last: []const f128 = padding_for_last(padded_at_start, end_point, self.allocator);
        defer self.allocator.free(padded_at_start_and_last);

        const wave: Wave = Wave.init(.{
            .samples = padded_at_start_and_last,
            .allocator = self.allocator,
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

    const empty_samples: []const f128 = generate_soundless_samples(end_point, self.allocator);
    defer self.allocator.free(empty_samples);

    var result: Wave = Wave.init(.{
        .samples = empty_samples,
        .allocator = self.allocator,
        .sample_rate = self.sample_rate,
        .channels = self.channels,
    });

    for (padded_waveinfo_slice) |waveinfo| {
        const wave = result.mix(waveinfo.wave, options);
        result.deinit();
        waveinfo.wave.deinit();
        result = wave;
    }

    return result;
}

/// Internal helper: Pad the start of wave samples with silence.
///
/// Prepends `start_point` samples of silence (0.0) to the beginning of the samples.
/// This is used to delay when a wave starts playing in the composition.
///
/// ## Parameters
///
/// - `samples`: Original wave samples
/// - `start_point`: Number of silent samples to prepend
/// - `allocator`: Allocator for the result
///
/// ## Returns
///
/// New slice with silence prepended. Caller must free.
fn padding_for_start(samples: []const f128, start_point: usize, allocator: std.mem.Allocator) []const f128 {
    const padding_length: usize = start_point;
    var padding: std.array_list.Aligned(f128, null) = .empty;
    defer padding.deinit(allocator);

    // Append padding
    for (0..padding_length) |_|
        padding.append(allocator, 0.0) catch @panic("Out of memory");

    // Append samples slice
    padding.appendSlice(allocator, samples) catch @panic("Out of memory");

    const result: []const f128 = padding.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

fn padding_for_last(samples: []const f128, end_point: usize, allocator: std.mem.Allocator) []const f128 {
    std.debug.assert(samples.len <= end_point);

    const padding_length: usize = end_point - samples.len;
    var padding: std.array_list.Aligned(f128, null) = .empty;
    defer padding.deinit(allocator);

    // Append samples slice
    padding.appendSlice(allocator, samples) catch @panic("Out of memory");

    // Append padding
    for (0..padding_length) |_|
        padding.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f128 = padding.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

fn generate_soundless_samples(length: usize, allocator: std.mem.Allocator) []const f128 {
    var list: std.array_list.Aligned(f128, null) = .empty;
    defer list.deinit(allocator);

    // Append empty wave
    for (0..length) |_|
        list.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f128 = list.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}

test "padding_for_start" {
    const allocator = testing.allocator;
    const samples: []const f128 = &[_]f128{ 1.0, 1.0 };
    const start_point: usize = 10;

    const result: []const f128 = padding_for_start(samples, start_point, allocator);
    defer allocator.free(result);

    try testing.expectEqual(samples.len + start_point, result.len);

    const expected: []const f128 = &[_]f128{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0 };
    for (0..result.len) |i| {
        try testing.expectApproxEqAbs(expected[i], result[i], 0.001);
    }
}

test "init & deinit" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();
}

test "init_with & deinit" {
    const allocator = testing.allocator;

    var reader = std.Io.Reader.fixed(@embedFile("assets/sine.wav"));
    const wave = Wave.read(&reader, allocator);
    defer wave.deinit();

    const info: []const WaveInfo = &[_]WaveInfo{ .{ .wave = wave, .start_point = 0 }, .{ .wave = wave, .start_point = 0 } };

    const composer = Self.init_with(.{
        .info = info,
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();
}

test "append" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var reader = std.Io.Reader.fixed(@embedFile("assets/sine.wav"));
    const wave = Wave.read(&reader, allocator);
    defer wave.deinit();

    const appended_composer = composer.append(.{ .wave = wave, .start_point = 0 });
    defer appended_composer.deinit();

    try testing.expectEqualSlices(WaveInfo, appended_composer.info, &[_]WaveInfo{.{ .wave = wave, .start_point = 0 }});
}

test "appendSlice" {
    const allocator = testing.allocator;
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var reader = std.Io.Reader.fixed(@embedFile("assets/sine.wav"));
    const wave = Wave.read(&reader, allocator);
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
    const composer = Self.init(.{
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    var samples: []f128 = try allocator.alloc(f128, 44100);
    defer allocator.free(samples);

    for (0..samples.len) |i| {
        samples[i] = 1.0;
    }

    const wave = Wave.init(.{
        .samples = samples,
        .allocator = allocator,
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

    const result: Wave = appended_composer.finalize(.{});
    defer result.deinit();

    try testing.expectEqual(result.samples.len, 88200);

    try testing.expectEqual(result.sample_rate, 44100);
    try testing.expectEqual(result.channels, 1);
}
