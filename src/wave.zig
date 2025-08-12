//! Wave

const std = @import("std");
const zig_wav = @import("zig_wav");
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

pub const Generators = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Generators {
        return Generators{ .allocator = allocator };
    }

    pub fn soundless(self: Generators, samples: usize) ![]const f32 {
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

    pub fn deinit(self: Generators, data: []const f32) void {
        self.allocator.free(data);
    }
};

pub fn init(data: []const f32, allocator: std.mem.Allocator, options: initOptions) !Self {
    const owned_data = try allocator.alloc(f32, data.len);
    @memcpy(owned_data, data);

    return Self{
        .data = owned_data,
        .allocator = allocator,

        .sample_rate = options.sample_rate,
        .channels = options.channels,
        .bits = options.bits,
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
    var decoder = try zig_wav.decoder(stream.reader());

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
    var encoder = try zig_wav.encoder(i16, file.writer(), file.seekableStream(), self.sample_rate, self.channels);
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
    const wave = try Self.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
    try testing.expectEqual(wave.bits, 16);
}

test "Generators.soundless" {
    const allocator = testing.allocator;
    const generators = Self.Generators.init(allocator);
    const data: []const f32 = try generators.soundless(44100);
    defer generators.deinit(data);

    const wave = try Self.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer wave.deinit();

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
    try testing.expectEqual(wave.bits, 16);

    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 0.0);
    try testing.expectEqual(wave.data[2], 0.0);
}
