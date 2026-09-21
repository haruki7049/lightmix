const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_it.deinit();

    _ = args_it.skip();
    const wav_path = args_it.next() orelse return error.MissingWavPathArgument;
    const expected_str = args_it.next() orelse return error.MissingExpectedTimestampArgument;
    const expected = try std.fmt.parseInt(u32, expected_str, 10);

    const file = try std.Io.Dir.cwd().openFile(io, wav_path, .{});
    defer file.close(io);

    const file_size = try file.length(io);
    var buf: [64 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    const bytes = try file_reader.interface.readAlloc(allocator, file_size);

    // Find the PEAK chunk and read its timestamp (version starts at +8, timestamp at +12)
    const peak_pos = std.mem.indexOf(u8, bytes, "PEAK") orelse return error.MissingPeakChunk;
    if (bytes.len < peak_pos + 16) return error.TruncatedPeakChunk;
    const timestamp = std.mem.readInt(u32, bytes[peak_pos + 12 ..][0..4], .little);

    // currentTimestamp must have produced a real (non-default) timestamp that reached the file intact
    if (timestamp == 0) return error.PeakTimestampNotSet;
    if (timestamp != expected) return error.MismatchedPeakTimestamp;
}
