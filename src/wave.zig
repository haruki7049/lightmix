//! Wave

const std = @import("std");
const lightmix_wav = @import("lightmix_wav");
const testing = std.testing;

const Self = @This();

data: []const f32,
allocator: std.mem.Allocator,

sample_rate: usize,
channels: usize,
bits: usize,

pub const initOptions = struct {
    sample_rate: usize,
    channels: usize,
    bits: usize,
};

pub fn init(data: []const f32, allocator: std.mem.Allocator, options: initOptions) Self {
    const owned_data = allocator.alloc(f32, data.len) catch @panic("Out of memory");
    @memcpy(owned_data, data);

    return Self{
        .data = owned_data,
        .allocator = allocator,

        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
    };
}

pub fn mix(self: Self, other: Self) !Self {
    std.debug.assert(self.data.len == other.data.len);
    std.debug.assert(self.sample_rate == other.sample_rate);
    std.debug.assert(self.channels == other.channels);
    std.debug.assert(self.bits == other.bits);

    if (self.data.len == 0)
        return Self{
            .data = &[_]f32{},
            .allocator = self.allocator,

            .sample_rate = self.sample_rate,
            .channels = self.channels,
            .bits = self.bits,
        };

    var result = std.ArrayList(f32).init(self.allocator);

    for (0 .. self.data.len) |i| {
        try result.append(self.data[i] + other.data[i]);
    }

    return Self{
        .data = try result.toOwnedSlice(),
        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
    };
}

pub fn fill_zero_to_end(self: Self, start: usize, end: usize) !Self {
    // Initialization
    var result = std.ArrayList(f32).init(self.allocator);
    try result.appendSlice(self.data);

    const delete_count: usize = result.items.len - start;

    for (0 .. delete_count) |_| {
        _ = result.pop();
    }

    std.debug.assert(start == result.items.len);

    for (delete_count .. end) |_| {
        try result.append(0.0);
    }

    std.debug.assert(result.items.len == end);

    return Self{
        .data = try result.toOwnedSlice(),
        .allocator = self.allocator,

        .sample_rate = self.sample_rate,
        .channels = self.channels,
        .bits = self.bits,
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
pub fn from_file_content(content: []const u8, allocator: std.mem.Allocator) !Self {
    var stream = std.io.fixedBufferStream(content);
    var decoder = try lightmix_wav.decoder(stream.reader());

    var buf: [64]f32 = undefined;
    var arraylist = std.ArrayList(f32).init(allocator);

    while (true) {
        // Read samples as f32. Channels are interleaved.
        const samples_read = try decoder.read(f32, &buf);

        // < ------ Do something with samples in buf. ------ >
        try arraylist.appendSlice(&buf);

        if (samples_read < buf.len) {
            break;
        }
    }

    const sample_rate: usize = decoder.sampleRate();
    const channels: usize = decoder.channels();
    const bits: usize = decoder.bits();

    return Self{
        .data = try arraylist.toOwnedSlice(),
        .allocator = allocator,

        .sample_rate = sample_rate,
        .channels = channels,
        .bits = bits,
    };
}

pub fn write(self: Self, file: std.fs.File) !void {
    var encoder = try lightmix_wav.encoder(i16, file.writer(), file.seekableStream(), self.sample_rate, self.channels);
    try encoder.write(f32, self.data);
    try encoder.finalize();
}

pub fn filter(self: Self, filter_fn: fn (self: Self) anyerror!Self) Self {
    const result: Self = filter_fn(self) catch |err| {
        std.debug.print("{any}\n", .{err});
        @panic("Error happened in filter function...");
    };

    return result;
}

test "from_file_content & deinit" {
    const allocator = testing.allocator;
    const wave = try Self.from_file_content(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 5.0109863e-2);
    try testing.expectEqual(wave.data[2], 1.0003662e-1);

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
    try testing.expectEqual(wave.bits, 16);
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
        .bits = 16,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
    try testing.expectEqual(wave.bits, 16);
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
        .bits = 16,
    });
    defer wave.deinit();

    const result: Self = try wave.mix(wave);
    defer result.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
    try testing.expectEqual(wave.bits, 16);

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
        .bits = 16,
    });
    defer wave.deinit();

    const filled_wave: Self = try wave.fill_zero_to_end(22050, 44100);
    defer filled_wave.deinit();

    try testing.expectEqual(filled_wave.sample_rate, 44100);
    try testing.expectEqual(filled_wave.channels, 1);
    try testing.expectEqual(filled_wave.bits, 16);

    try testing.expectEqual(filled_wave.data[0], 0.0);
    try testing.expectEqual(filled_wave.data[1], 3.1324163e-2);
    try testing.expectEqual(filled_wave.data[2], 6.2525265e-2);

    try testing.expectEqual(filled_wave.data[22049], -3.1344667e-2);
    try testing.expectEqual(filled_wave.data[22050], 0.0);
    try testing.expectEqual(filled_wave.data[22051], 0.0);
    try testing.expectEqual(filled_wave.data[44099], 0.0);
}
