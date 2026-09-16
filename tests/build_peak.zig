const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var args_it = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args_it.deinit();

    _ = args_it.skip();
    const wav_path = args_it.next() orelse return error.MissingWavPathArgument;

    const file = try std.Io.Dir.cwd().openFile(io, wav_path, .{});
    defer file.close(io);

    const file_size = try file.length(io);
    var buf: [64 * 1024]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    const bytes = try file_reader.interface.readAlloc(allocator, file_size);

    // Verify WAV RIFF header
    if (bytes.len < 12) return error.InvalidWavHeader;
    if (!std.mem.eql(u8, bytes[0..4], "RIFF")) return error.InvalidRiffSignature;
    if (!std.mem.eql(u8, bytes[8..12], "WAVE")) return error.InvalidWaveSignature;

    // Check that "PEAK" chunk signature is present in the file
    const peak_pos = std.mem.indexOf(u8, bytes, "PEAK") orelse return error.MissingPeakChunk;

    // Verify timestamp in PEAK chunk (version starts at +8, timestamp at +12)
    if (bytes.len < peak_pos + 16) return error.TruncatedPeakChunk;
    const timestamp = std.mem.readInt(u32, bytes[peak_pos + 12 ..][0..4], .little);
    if (timestamp != 1700000000) return error.MismatchedPeakTimestamp;

    // Verify Wave(f64).read can parse the WAV file containing PEAK chunk
    var reader = std.Io.Reader.fixed(bytes);
    const wave = try Wave(f64).read(.wav, allocator, &reader);
    defer wave.deinit();

    if (wave.samples.len == 0) return error.EmptySamples;
}
