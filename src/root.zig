//! By convention, root.zig is the root source file when making a library. If
//! you are making an executable, the convention is to delete this file and
//! start with main.zig instead.
const std = @import("std");
const zig_wav = @import("zig_wav");
const testing = std.testing;

const Wave = struct {
    const Self = @This();

    inner: []const f32,
    allocator: std.mem.Allocator,

    /// Create Wave from binary data
    /// The data argument can receive a binary data, as @embedFile("./assets/sine.wav")
    /// Therefore you can use this function as:
    /// const wave = Wave.init(@embedFile("./asset/sine.wav"));
    fn init(data: []const u8, allocator: std.mem.Allocator) !Self {
        var stream = std.io.fixedBufferStream(data);
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

        return Self{
            .inner = try arraylist.toOwnedSlice(),
            .allocator = allocator
        };
    }

    /// Free the Wave struct
    fn deinit(self: Self) void {
        self.allocator.free(self.inner);
    }
};

test "init" {
    const allocator = testing.allocator;
    const wave = try Wave.init(@embedFile("./assets/sine.wav"), allocator);
    defer wave.deinit();

    try testing.expectEqual(wave.inner[0], 0.0);
    try testing.expectEqual(wave.inner[1], 5.0109863e-2);
    try testing.expectEqual(wave.inner[2], 1.0003662e-1);
}
