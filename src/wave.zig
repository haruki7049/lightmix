const std = @import("std");
const zigggwavvv = @import("zigggwavvv");

const Self = @This();

allocator: std.mem.Allocator,
data: []const f128,
sample_rate: u32,
channels: u16,

pub fn deinit(self: Self) void {
    self.allocator.free(self.data);
}

pub const mixOptions = struct {
    mixer: fn (f128, f128) f128 = default_mixing_expression,
};

pub fn default_mixing_expression(left: f128, right: f128) f128 {
    return left + right;
}

pub fn mix(self: Self, other: Self, options: mixOptions) Self {
    std.debug.assert(self.data.len == other.data.len);
    std.debug.assert(self.sample_rate == other.sample_rate);
    std.debug.assert(self.channels == other.channels);

    if (self.data.len == 0)
        return Self{
            .allocator = self.allocator,
            .data = &[_]f128{},
            .sample_rate = self.sample_rate,
            .channels = self.channels,
        };

    var data: std.array_list.Aligned(f128, null) = .empty;

    for (0..self.data.len) |i| {
        const left: f128 = self.data[i];
        const right: f128 = other.data[i];
        const result: f128 = options.mixer(left, right);

        data.append(self.allocator, result) catch @panic("Out of memory");
    }

    const result = data.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .allocator = self.allocator,
        .data = result,
        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

pub fn fill_zero_to_end(
    self: Self,
    start: usize,
    end: usize,
) !Self {
    // Initialization
    var result: std.array_list.Aligned(f128, null) = .empty;
    try result.appendSlice(self.allocator, self.data);

    const delete_count: usize = result.items.len - start;

    for (0..delete_count) |_| {
        _ = result.pop();
    }

    std.debug.assert(start == result.items.len);

    for (delete_count..end) |_| {
        try result.append(self.allocator, 0.0);
    }

    std.debug.assert(result.items.len == end);

    return Self{
        .data = try result.toOwnedSlice(self.allocator),
        .allocator = self.allocator,
        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

pub fn read(
    bits: u16,
    format_code: zigggwavvv.FormatCode,
    reader: anytype,
    allocator: std.mem.Allocator,
) anyerror!Self {
    const zigggwavvv_wave = try zigggwavvv.read(allocator, reader);

    if (bits != zigggwavvv_wave.bits)
        return error.InvalidBits;

    if (format_code != zigggwavvv_wave.format_code)
        return error.InvalidFormatCode;

    return Self{
        .allocator = allocator,
        .sample_rate = zigggwavvv_wave.sample_rate,
        .channels = zigggwavvv_wave.channels,
        .data = zigggwavvv_wave.samples,
    };
}

pub const WriteOptions = struct {
    bits: u16,
    format_code: zigggwavvv.FormatCode,
    use_fact: bool = false,
    use_peak: bool = false,
    peak_timestamp: u32 = 0,
};

pub fn write(
    self: Self,
    writer: anytype,
    options: WriteOptions,
) !void {
    const zigggwavvv_wave = zigggwavvv.Wave{
        .format_code = options.format_code,
        .bits = options.bits,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .data = self.data,
    };

    try zigggwavvv.write(zigggwavvv_wave, writer, .{
        .allocator = self.allocator,
        .use_fact = options.use_fact,
        .use_peak = options.use_peak,
        .peak_timestamp = options.peak_timestamp,
    });
}

pub fn filter(
    self: Self,
    filter_fn: fn (self: Self) anyerror!Self,
) Self {
    const result: Self = filter_fn(self) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter function...");
    };

    return result;
}

pub fn filter_with(
    self: Self,
    comptime args_type: type,
    filter_fn: fn (self: Self, args: args_type) anyerror!Self,
    args: args_type,
) Self {
    const result: Self = filter_fn(self, args) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter_with function...");
    };

    return result;
}

test "read & deinit" {
    const allocator = std.testing.allocator;

    var reader = std.Io.Reader.fixed(@embedFile("./assets/sine.wav"));
    const wave = try Self.read(16, .pcm, &reader, allocator);
    defer wave.deinit();

    const expected_data: []const f128 = &[_]f128{
        0,
        0.050111392559587389751884517960142825,
        0.1000396740623187963499862666707358,
        0.14960173345133823664052247688222907,
        0.19849238563188573870052186651203955,
        0.24665059358500930814539017914365063,
        0.2939542832728049562059389019440291,
        0.33979308450575273903622547074800867,
        0.38474684896389660328989532151249733,
        0.42771691030610065004425183874019593,
        0.46934415723136082033753471480452893,
        0.5090182195501571703238013855403302,
        0.5465865047151097140415662099063082,
        0.582262642292550431836909085360271,
        0.6153447065645313882869960631122776,
        0.6462599566637165440839869380779442,
    };
    try std.testing.expectEqualSlices(f128, wave.data[0..16], expected_data);

    try std.testing.expectEqual(wave.sample_rate, 44100);
    try std.testing.expectEqual(wave.channels, 1);
}

fn generate_sine_testdata() []f128 {
    const sample_rate: f128 = 44100.0;
    const radins_per_sec: f128 = 440.0 * 2.0 * std.math.pi;

    var result: [44100]f128 = undefined;

    for (0..44100) |i| {
        result[i] = 0.5 * std.math.sin(@as(f128, @floatFromInt(i)) * radins_per_sec / sample_rate);
    }

    return &result;
}

test "init & deinit" {
    const allocator = std.testing.allocator;
    const data = generate_sine_testdata();
    const wave = Self{
        .allocator = allocator,
        .data = data[0..],
        .sample_rate = 44100,
        .channels = 1,
    };

    try std.testing.expectEqual(wave.sample_rate, 44100);
    try std.testing.expectEqual(wave.channels, 1);
}

test "mix" {
    const allocator = std.testing.allocator;

    const data = generate_sine_testdata();
    const wave = Self{
        .allocator = allocator,
        .data = data[0..],
        .sample_rate = 44100,
        .channels = 1,
    };

    const result: Self = wave.mix(wave, .{});
    defer result.deinit();

    try std.testing.expectEqual(result.sample_rate, 44100);
    try std.testing.expectEqual(result.channels, 1);

    const expected_data: []const f128 = &[_]f128{
        0,
        0.062648324178743691748039168487594,
        0.12505052369452809846173124697088497,
        0.18696144082725335566763646966137458,
        0.2481378479437378881122810980741633,
        0.30833940305910034762604254865436815,
        0.36732959406137882796272720042907167,
        0.4248766678898384108187258334510261,
        0.480754541016531700137193183763884,
        0.5347436876541296069120789979933761,
        0.5866320022005455658842265620478429,
        0.6362156325320930116973272561153863,
        0.6832997808714387222295272295014001,
        0.727699469084009398223145126394229,
        0.7692402653962486791527908280841075,
        0.8077589696806923846850168047240004,
    };
    try std.testing.expectEqualSlices(f128, result.data[0..16], expected_data);
}

test "fill_zero_to_end" {
    const allocator = std.testing.allocator;

    const data = generate_sine_testdata();
    const wave = Self{
        .allocator = allocator,
        .data = data[0..],
        .sample_rate = 44100,
        .channels = 1,
    };

    const filled_wave: Self = try wave.fill_zero_to_end(22050, 44100);
    defer filled_wave.deinit();

    try std.testing.expectEqual(filled_wave.sample_rate, 44100);
    try std.testing.expectEqual(filled_wave.channels, 1);

    try std.testing.expectEqual(filled_wave.data[0], 0.0);
    try std.testing.expectEqual(filled_wave.data[1], 0.031324162089371845874019584243797);
    try std.testing.expectEqual(filled_wave.data[2], 0.06252526184726404923086562348544248);

    try std.testing.expectEqual(filled_wave.data[22049], -0.03132416208941617846717164752590179);
    try std.testing.expectEqual(filled_wave.data[22050], 0.0);
    try std.testing.expectEqual(filled_wave.data[22051], 0.0);
    try std.testing.expectEqual(filled_wave.data[44099], 0.0);
}

test "filter_with" {
    const allocator = std.testing.allocator;
    const data: []const f128 = &[_]f128{};

    const wave = (Self{
        .allocator = allocator,
        .data = data,
        .sample_rate = 44100,
        .channels = 1,
    }).filter_with(ArgsForTesting, test_filter_with_args, .{ .data = 3 });
    defer wave.deinit();

    try std.testing.expectEqual(wave.sample_rate, 44100);
    try std.testing.expectEqual(wave.channels, 1);

    try std.testing.expectEqual(wave.data.len, 3);
    try std.testing.expectEqualSlices(f128, wave.data, &[_]f128{ 0.0, 0.0, 0.0 });
}

fn test_filter_with_args(
    original_wave: Self,
    args: ArgsForTesting,
) !Self {
    var result: []f128 = try original_wave.allocator.alloc(f128, args.data);
    defer original_wave.allocator.free(result);

    for (0..args.data) |i|
        result[i] = 0.0;

    return Self{
        .allocator = original_wave.allocator,
        .data = try original_wave.allocator.dupe(f128, result),
        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

const ArgsForTesting = struct {
    data: usize,
};

//test "filter" {
//    const allocator = testing.allocator;
//    const data: []const f32 = &[_]f32{};
//    const wave = Self.init(data, allocator, .{
//        .sample_rate = 44100,
//        .channels = 1,
//    })
//        .filter(test_filter_without_args);
//    defer wave.deinit();
//
//    try testing.expectEqual(wave.sample_rate, 44100);
//    try testing.expectEqual(wave.channels, 1);
//
//    try testing.expectEqual(wave.data.len, 5);
//    try testing.expectEqual(wave.data[0], 0.0);
//    try testing.expectEqual(wave.data[1], 0.0);
//    try testing.expectEqual(wave.data[2], 0.0);
//    try testing.expectEqual(wave.data[3], 0.0);
//    try testing.expectEqual(wave.data[4], 0.0);
//}
//
//fn test_filter_without_args(original_wave: Self) !Self {
//    var result: std.array_list.Aligned(f32, null) = .empty;
//
//    for (0..5) |_|
//        try result.append(original_wave.allocator, 0.0);
//
//    return Self{
//        .data = try result.toOwnedSlice(original_wave.allocator),
//        .allocator = original_wave.allocator,
//
//        .sample_rate = original_wave.sample_rate,
//        .channels = original_wave.channels,
//    };
//}
//
//test "filter memory leaks' check" {
//    const allocator = testing.allocator;
//    const data: []const f32 = &[_]f32{};
//    const wave = Self.init(data, allocator, .{
//        .sample_rate = 44100,
//        .channels = 1,
//    })
//        .filter(test_filter_without_args)
//        .filter(test_filter_without_args)
//        .filter(test_filter_without_args)
//        .filter(test_filter_without_args);
//    defer wave.deinit();
//
//    try testing.expectEqual(wave.sample_rate, 44100);
//    try testing.expectEqual(wave.channels, 1);
//
//    try testing.expectEqual(wave.data.len, 5);
//    try testing.expectEqual(wave.data[0], 0.0);
//    try testing.expectEqual(wave.data[1], 0.0);
//    try testing.expectEqual(wave.data[2], 0.0);
//    try testing.expectEqual(wave.data[3], 0.0);
//    try testing.expectEqual(wave.data[4], 0.0);
//}
//
//test "init with empty data" {
//    const allocator = testing.allocator;
//    const data: []const f32 = &[_]f32{};
//    const wave = Self.init(data, allocator, .{
//        .sample_rate = 44100,
//        .channels = 1,
//    });
//    defer wave.deinit();
//
//    try testing.expectEqual(wave.data.len, 0);
//    try testing.expectEqual(wave.sample_rate, 44100);
//    try testing.expectEqual(wave.channels, 1);
//}
//
//test "init creates deep copy of data" {
//    const allocator = testing.allocator;
//    var original_data = [_]f32{ 1.0, 2.0, 3.0 };
//    const wave = Self.init(&original_data, allocator, .{
//        .sample_rate = 44100,
//        .channels = 1,
//    });
//    defer wave.deinit();
//
//    // Modify original data
//    original_data[0] = 999.0;
//
//    // Wave data should be unchanged (deep copy was made)
//    try testing.expectEqual(wave.data[0], 1.0);
//    try testing.expectEqual(wave.data[1], 2.0);
//    try testing.expectEqual(wave.data[2], 3.0);
//}
//
//test "init with different channels" {
//    const allocator = testing.allocator;
//    const data: []const f32 = &[_]f32{ 1.0, 2.0, 3.0, 4.0 };
//
//    // Mono
//    const wave_mono = Self.init(data, allocator, .{
//        .sample_rate = 44100,
//        .channels = 1,
//    });
//    defer wave_mono.deinit();
//    try testing.expectEqual(wave_mono.channels, 1);
//
//    // Stereo
//    const wave_stereo = Self.init(data, allocator, .{
//        .sample_rate = 44100,
//        .channels = 2,
//    });
//    defer wave_stereo.deinit();
//    try testing.expectEqual(wave_stereo.channels, 2);
//}
//
//test "mix preserves wave properties" {
//    const allocator = testing.allocator;
//    const data1: []const f32 = &[_]f32{ 1.0, 2.0, 3.0 };
//    const data2: []const f32 = &[_]f32{ 0.5, 1.0, 1.5 };
//
//    const wave1 = Self.init(data1, allocator, .{
//        .sample_rate = 48000,
//        .channels = 2,
//    });
//    defer wave1.deinit();
//
//    const wave2 = Self.init(data2, allocator, .{
//        .sample_rate = 48000,
//        .channels = 2,
//    });
//    defer wave2.deinit();
//
//    const result = wave1.mix(wave2, .{});
//    defer result.deinit();
//
//    try testing.expectEqual(result.sample_rate, 48000);
//    try testing.expectEqual(result.channels, 2);
//    try testing.expectEqual(result.data.len, 3);
//    try testing.expectEqual(result.data[0], 1.5);
//    try testing.expectEqual(result.data[1], 3.0);
//    try testing.expectEqual(result.data[2], 4.5);
//}
//
//test "from_file_content with different sample rates" {
//    const allocator = testing.allocator;
//    const wave = Self.from_file_content(.i16, @embedFile("./assets/sine.wav"), allocator);
//    defer wave.deinit();
//
//    // Verify the wave has valid properties
//    try testing.expect(wave.sample_rate > 0);
//    try testing.expect(wave.channels > 0);
//    try testing.expect(wave.data.len > 0);
//}
