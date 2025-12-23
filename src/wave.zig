//! # Wave
//!
//! Contains a wave data.

const std = @import("std");
const build_options = @import("build_options");
const lightmix_wav = @import("lightmix_wav");
const known_folders = @import("known-folders");
const testing = std.testing;

const Self = @This();

/// A wave data, expressed by array contains f32.
data: []const f32,

/// An allocator
allocator: std.mem.Allocator,

/// This wave's sample rate.
sample_rate: usize,

/// This wave's channels.
channels: usize,

pub const Options = struct {
    sample_rate: usize,
    channels: usize,
};

/// Initialize a Wave with wave data (`[]const f32`).
pub fn init(
    data: []const f32,
    allocator: std.mem.Allocator,
    options: Options,
) Self {
    const owned_data = allocator.alloc(f32, data.len) catch @panic("Out of memory");
    @memcpy(owned_data, data);

    return Self{
        .data = owned_data,
        .allocator = allocator,

        .sample_rate = options.sample_rate,
        .channels = options.channels,
    };
}

/// Mix a wave and the other wave.
/// The each wave data's length, sample_rate, and channels must be same.
/// That's because we cannot adjust the timing for every users which the each wave should be played.
pub fn mix(self: Self, other: Self) Self {
    std.debug.assert(self.data.len == other.data.len);
    std.debug.assert(self.sample_rate == other.sample_rate);
    std.debug.assert(self.channels == other.channels);

    if (self.data.len == 0)
        return Self{
            .data = &[_]f32{},
            .allocator = self.allocator,

            .sample_rate = self.sample_rate,
            .channels = self.channels,
        };

    var data: std.array_list.Aligned(f32, null) = .empty;

    for (0..self.data.len) |i| {
        data.append(self.allocator, self.data[i] + other.data[i]) catch @panic("Out of memory");
    }

    const result: []const f32 = data.toOwnedSlice(self.allocator) catch @panic("Out of memory");

    return Self{
        .data = result,
        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
    };
}

pub fn fill_zero_to_end(self: Self, start: usize, end: usize) !Self {
    // Initialization
    var result: std.array_list.Aligned(f32, null) = .empty;
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

/// Free the Wave struct
pub fn deinit(self: Self) void {
    self.allocator.free(self.data);
}

/// Create Wave from binary data
/// The data argument can receive a binary data, as @embedFile("./assets/sine.wav")
/// Therefore you can use this function as:
/// const wave = Wave.from_file_content(@embedFile("./asset/sine.wav"), allocator);
pub fn from_file_content(
    bit_type: lightmix_wav.BitType,
    content: []const u8,
    allocator: std.mem.Allocator,
) Self {
    var stream = std.io.fixedBufferStream(content);
    var decoder = lightmix_wav.decoder(stream.reader()) catch |err| {
        std.debug.print("In lightmix_wav\n", .{});
        std.debug.print("{any}\n", .{err});
        @panic("Failed to create decoder");
    };

    std.debug.assert(bit_type == decoder.bits());

    var buf: [64]f32 = undefined;
    var arraylist: std.array_list.Aligned(f32, null) = .empty;

    while (true) {
        // Read samples as f32. Channels are interleaved.
        const samples_read = decoder.read(f32, &buf) catch |err| {
            std.debug.print("In lightmix_wav\n", .{});
            std.debug.print("{any}\n", .{err});
            @panic("Failed to read samples from decoder");
        };

        // < ------ Do something with samples in buf. ------ >
        arraylist.appendSlice(allocator, &buf) catch @panic("Out of memory");

        if (samples_read < buf.len) {
            break;
        }
    }

    const result: []const f32 = arraylist.toOwnedSlice(allocator) catch @panic("Out of memory");

    const sample_rate: usize = decoder.sampleRate();
    const channels: usize = decoder.channels();

    return Self{
        .data = result,
        .allocator = allocator,

        .sample_rate = sample_rate,
        .channels = channels,
    };
}

/// Writes down the wave data to `std.fs.File`.
pub fn write(self: Self, file: std.fs.File, comptime bits: lightmix_wav.BitType) !void {
    var encoder = try lightmix_wav.encoder(bits, file, self.sample_rate, self.channels);
    try encoder.write(f32, self.data);
    try encoder.finalize();
}

/// Filters a zig function.
/// Use this function as `wave.filter_with(Args, your_filter, .{ args = 0 });`
/// This function uses self.deinit() to avoid the memory leaks by not free the data arrays
pub fn filter_with(
    self: Self,
    comptime args_type: type,
    filter_fn: fn (self: Self, args: args_type) anyerror!Self,
    args: args_type,
) Self {
    // To destroy original data array
    // If we don't do this, we may catch some memory leaks by not to free original data array
    defer self.deinit();

    const result: Self = filter_fn(self, args) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter_with function...");
    };

    return result;
}

/// Filters a zig function.
/// Use this function as `wave.filter(your_filter);`
/// This function uses self.deinit() to avoid the memory leaks by not free the data arrays
pub fn filter(
    self: Self,
    filter_fn: fn (self: Self) anyerror!Self,
) Self {
    // To destroy original data array
    // If we don't do this, we may catch some memory leaks by not to free original data array
    defer self.deinit();

    const result: Self = filter_fn(self) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter function...");
    };

    return result;
}

/// Plays the wave instantly.
/// You must enable `with_debug_features` in `build.zig`.
pub fn debug_play(self: Self, comptime bit_type: lightmix_wav.BitType) !void {
    if (!build_options.with_debug_features)
        @panic("Wave.debug_play called without 'with_debug_features' flag. Please turn on the flag.");

    const cache_dir: std.fs.Dir = try known_folders.open(self.allocator, .cache, .{}) orelse @panic("XDG cache dir is null");
    cache_dir.access("lightmix", .{}) catch {
        try cache_dir.makeDir("lightmix");
    };

    const path: []const u8 = blk: {
        const cache_dir_path: []const u8 = try known_folders.getPath(self.allocator, .cache) orelse @panic("XDG cache dir is null");
        const now: std.time.Instant = try std.time.Instant.now();

        const result: []const u8 = try std.fmt.allocPrint(self.allocator, "{s}/lightmix/result-{d}.{d}.wav", .{ cache_dir_path, now.timestamp.sec, now.timestamp.nsec });
        break :blk result;
    };
    defer self.allocator.free(path);

    const file = try cache_dir.createFile(path, .{});

    try self.write(file, bit_type);
    std.debug.print("Wave file saved to: {s}\n", .{path});

    // Debug-play

    std.debug.print("Debug-playing...\n", .{});

    const c_headers = @cImport({
        @cInclude("portaudio.h");
        @cInclude("sndfile.h");
    });

    const c_path: [*c]const u8 = try self.allocator.dupeZ(u8, path);

    var sfInfo: c_headers.SF_INFO = undefined;
    const sndFile: ?*c_headers.SNDFILE = c_headers.sf_open(c_path, c_headers.SFM_READ, &sfInfo);
    defer _ = c_headers.sf_close(sndFile);

    if (c_headers.Pa_Initialize() != c_headers.paNoError)
        return error.PortaudioInitFailed;

    defer _ = c_headers.Pa_Terminate();

    var stream: ?*c_headers.PaStream = undefined;

    if (c_headers.Pa_OpenDefaultStream(
        &stream,
        0,
        @intCast(self.channels),
        c_headers.paFloat32,
        @as(f64, @floatFromInt(self.sample_rate)),
        256,
        null,
        null,
    ) != c_headers.paNoError)
        return error.PortaudioFailedToOpenStream;

    defer _ = c_headers.Pa_CloseStream(stream.?);

    if (c_headers.Pa_StartStream(stream) != c_headers.paNoError)
        return error.PortaudioStartStreamFailed;

    defer _ = c_headers.Pa_StopStream(stream);

    var buffer: [256 * 2]f32 = undefined; // stereo
    var framesRead: i64 = undefined;

    while (true) {
        framesRead = c_headers.sf_readf_float(sndFile, &buffer, 256);

        if (c_headers.Pa_WriteStream(stream, &buffer, @intCast(framesRead)) != c_headers.paNoError)
            break;

        if (framesRead <= 0)
            break;
    }

    std.debug.print("Debug-playing finished.\n", .{});
}

const DebugPlayErrors = error{
    PortaudioInitFailed,
    PortaudioFailedToOpenStream,
    PortaudioStartStreamFailed,
};

test "from_file_content & deinit" {
    const allocator = testing.allocator;
    const wave = Self.from_file_content(.i16, @embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 5.0109863e-2);
    try testing.expectEqual(wave.data[2], 1.0003662e-1);

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
}

test "init & deinit" {
    const allocator = testing.allocator;

    const generator = struct {
        fn sinewave() [44100]f32 {
            const sample_rate: f32 = 44100.0;
            const radins_per_sec: f32 = 440.0 * 2.0 * std.math.pi;

            var result: [44100]f32 = undefined;
            var i: usize = 0;

            while (i < result.len) : (i += 1) {
                result[i] = 0.5 * std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate);
            }

            return result;
        }
    };

    const data: [44100]f32 = generator.sinewave();
    const wave = Self.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
}

test "mix" {
    const allocator = testing.allocator;
    const generator = struct {
        fn sinewave() [44100]f32 {
            const sample_rate: f32 = 44100.0;
            const radins_per_sec: f32 = 440.0 * 2.0 * std.math.pi;

            var result: [44100]f32 = undefined;
            var i: usize = 0;

            while (i < result.len) : (i += 1) {
                result[i] = 0.5 * std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate);
            }

            return result;
        }
    };

    const data: [44100]f32 = generator.sinewave();
    const wave = Self.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const result: Self = wave.mix(wave);
    defer result.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(result.data[0], 0.0);
    try testing.expectEqual(result.data[1], 6.2648326e-2);
    try testing.expectEqual(result.data[2], 1.2505053e-1);
}

test "fill_zero_to_end" {
    const allocator = testing.allocator;
    const generator = struct {
        fn sinewave() [44100]f32 {
            const sample_rate: f32 = 44100.0;
            const radins_per_sec: f32 = 440.0 * 2.0 * std.math.pi;

            var result: [44100]f32 = undefined;
            var i: usize = 0;

            while (i < result.len) : (i += 1) {
                result[i] = 0.5 * std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate);
            }

            return result;
        }
    };

    const data: [44100]f32 = generator.sinewave();
    const wave = Self.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    const filled_wave: Self = try wave.fill_zero_to_end(22050, 44100);
    defer filled_wave.deinit();

    try testing.expectEqual(filled_wave.sample_rate, 44100);
    try testing.expectEqual(filled_wave.channels, 1);

    try testing.expectEqual(filled_wave.data[0], 0.0);
    try testing.expectEqual(filled_wave.data[1], 3.1324163e-2);
    try testing.expectEqual(filled_wave.data[2], 6.2525265e-2);

    try testing.expectEqual(filled_wave.data[22049], -3.1344667e-2);
    try testing.expectEqual(filled_wave.data[22050], 0.0);
    try testing.expectEqual(filled_wave.data[22051], 0.0);
    try testing.expectEqual(filled_wave.data[44099], 0.0);
}

test "filter_with" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{};
    const wave = Self.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    })
        .filter_with(ArgsForTesting, test_filter_with_args, .{ .samples = 3 });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(wave.data.len, 3);
    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 0.0);
    try testing.expectEqual(wave.data[2], 0.0);
}

fn test_filter_with_args(
    original_wave: Self,
    args: ArgsForTesting,
) !Self {
    var result: std.array_list.Aligned(f32, null) = .empty;

    for (0..args.samples) |_|
        try result.append(original_wave.allocator, 0.0);

    return Self{
        .data = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

const ArgsForTesting = struct {
    samples: usize,
};

test "filter" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{};
    const wave = Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    })
        .filter(test_filter_without_args);
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(wave.data.len, 5);
    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 0.0);
    try testing.expectEqual(wave.data[2], 0.0);
    try testing.expectEqual(wave.data[3], 0.0);
    try testing.expectEqual(wave.data[4], 0.0);
}

fn test_filter_without_args(original_wave: Self) !Self {
    var result: std.array_list.Aligned(f32, null) = .empty;

    for (0..5) |_|
        try result.append(original_wave.allocator, 0.0);

    return Self{
        .data = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

test "filter memory leaks' check" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{};
    const wave = Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    })
        .filter(test_filter_without_args)
        .filter(test_filter_without_args)
        .filter(test_filter_without_args)
        .filter(test_filter_without_args);
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);

    try testing.expectEqual(wave.data.len, 5);
    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 0.0);
    try testing.expectEqual(wave.data[2], 0.0);
    try testing.expectEqual(wave.data[3], 0.0);
    try testing.expectEqual(wave.data[4], 0.0);
}

test "init with empty data" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{};
    const wave = Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.data.len, 0);
    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
}

test "init creates deep copy of data" {
    const allocator = testing.allocator;
    var original_data = [_]f32{ 1.0, 2.0, 3.0 };
    const wave = Self.init(&original_data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // Modify original data
    original_data[0] = 999.0;

    // Wave data should be unchanged (deep copy was made)
    try testing.expectEqual(wave.data[0], 1.0);
    try testing.expectEqual(wave.data[1], 2.0);
    try testing.expectEqual(wave.data[2], 3.0);
}

test "init with different channels" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{ 1.0, 2.0, 3.0, 4.0 };

    // Mono
    const wave_mono = Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave_mono.deinit();
    try testing.expectEqual(wave_mono.channels, 1);

    // Stereo
    const wave_stereo = Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 2,
    });
    defer wave_stereo.deinit();
    try testing.expectEqual(wave_stereo.channels, 2);
}

test "mix preserves wave properties" {
    const allocator = testing.allocator;
    const data1: []const f32 = &[_]f32{ 1.0, 2.0, 3.0 };
    const data2: []const f32 = &[_]f32{ 0.5, 1.0, 1.5 };

    const wave1 = Self.init(data1, allocator, .{
        .sample_rate = 48000,
        .channels = 2,
    });
    defer wave1.deinit();

    const wave2 = Self.init(data2, allocator, .{
        .sample_rate = 48000,
        .channels = 2,
    });
    defer wave2.deinit();

    const result = wave1.mix(wave2);
    defer result.deinit();

    try testing.expectEqual(result.sample_rate, 48000);
    try testing.expectEqual(result.channels, 2);
    try testing.expectEqual(result.data.len, 3);
    try testing.expectEqual(result.data[0], 1.5);
    try testing.expectEqual(result.data[1], 3.0);
    try testing.expectEqual(result.data[2], 4.5);
}

test "write to file" {
    const allocator = testing.allocator;
    const data: []const f32 = &[_]f32{ 0.0, 0.1, 0.2, 0.3, 0.4 };

    const wave = Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    // Create a temporary file
    const test_dir = testing.tmpDir(.{});
    const test_file = try test_dir.dir.createFile("test_wave.wav", .{});
    defer {
        test_file.close();
        test_dir.cleanup();
    }

    // Write wave to file
    try wave.write(test_file, .i16);

    // Verify file was created and has content
    const file_stat = try test_file.stat();
    try testing.expect(file_stat.size > 0);
}

test "from_file_content with different sample rates" {
    const allocator = testing.allocator;
    const wave = Self.from_file_content(.i16, @embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    // Verify the wave has valid properties
    try testing.expect(wave.sample_rate > 0);
    try testing.expect(wave.channels > 0);
    try testing.expect(wave.data.len > 0);
}
