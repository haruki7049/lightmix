//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const zig_wav = @import("zig_wav");
const testing = std.testing;

pub const Wave = struct {
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
};

test "init & deinit" {
    const allocator = testing.allocator;
    const wave = try Wave.init(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    try testing.expectEqual(wave.data[0], 0.0);
    try testing.expectEqual(wave.data[1], 5.0109863e-2);
    try testing.expectEqual(wave.data[2], 1.0003662e-1);

    try testing.expectEqual(wave.sample_rate, 44100);
    try testing.expectEqual(wave.channels, 1);
    try testing.expectEqual(wave.bits, 16);
}
