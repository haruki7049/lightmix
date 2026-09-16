const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;

test "Compose multiple soundless Wave" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var composer = Composer(f64).init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    const data: []const f64 = try generate_soundless_data(44100, allocator);
    defer allocator.free(data);

    const wave: Wave(f64) = try Wave(f64).init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    var append_list: std.array_list.Aligned(Composer(f64).WaveInfo, null) = .empty;
    defer append_list.deinit(allocator);
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });

    try composer.appendSlice(append_list.items);

    const result = try composer.finalize(.{});
    defer result.deinit();

    // Create TmpDir
    var tmpDir = std.testing.tmpDir(.{});
    defer tmpDir.cleanup();

    var file = try tmpDir.dir.createFile(io, "result.wav", .{});
    defer file.close(io);
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(io, buf);

    // Write Wave into the file
    try result.write(.wav, &writer.interface, .{
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    // Read the written wave file
    const result_bytes = try tmpDir.dir.readFileAlloc(io, "result.wav", allocator, .limited(100 * 1024 * 1024));
    defer allocator.free(result_bytes);

    // Read the actual file
    const expected_bytes = try std.Io.Dir.cwd().readFileAlloc(io, "tests/assets/soundless.wav", allocator, .limited(100 * 1024 * 1024));
    defer allocator.free(expected_bytes);

    try std.testing.expectEqualSlices(u8, expected_bytes, result_bytes);
}

test "Composer finalize empty composition" {
    const allocator = std.testing.allocator;
    const composer = Composer(f64).init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    const result = try composer.finalize(.{});
    defer result.deinit();

    try std.testing.expectEqual(result.samples.len, 0);
    try std.testing.expectEqual(result.sample_rate, 44100);
    try std.testing.expectEqual(result.channels, 1);
}

test "Composer append with unaligned channel offset returns error" {
    const allocator = std.testing.allocator;
    var composer = Composer(f64).init(allocator, .{
        .sample_rate = 44100,
        .channels = 2,
    });
    defer composer.deinit();

    const data = [_]f64{ 0.1, 0.2, 0.3, 0.4 };
    const wave = try Wave(f64).init(&data, allocator, .{
        .sample_rate = 44100,
        .channels = 2,
    });
    defer wave.deinit();

    try std.testing.expectError(error.UnalignedChannelOffset, composer.append(.{ .wave = wave, .start_point = 1 }));
}

test "Compose sine waves and verify exported WAV file roundtrip" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;

    var composer = Composer(f64).init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    // Generate 440 Hz sine wave for 0.1s (4410 samples)
    var samples1: [4410]f64 = undefined;
    for (0..samples1.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / 44100.0;
        samples1[i] = 0.4 * @sin(t * 440.0 * 2.0 * std.math.pi);
    }
    const wave1 = try Wave(f64).init(&samples1, allocator, .{ .sample_rate = 44100, .channels = 1 });
    defer wave1.deinit();

    // Generate 880 Hz sine wave for 0.1s (4410 samples)
    var samples2: [4410]f64 = undefined;
    for (0..samples2.len) |i| {
        const t = @as(f64, @floatFromInt(i)) / 44100.0;
        samples2[i] = 0.3 * @sin(t * 880.0 * 2.0 * std.math.pi);
    }
    const wave2 = try Wave(f64).init(&samples2, allocator, .{ .sample_rate = 44100, .channels = 1 });
    defer wave2.deinit();

    // Append wave1 at start_point 0, wave2 at start_point 2205 (staggered overlap)
    try composer.append(.{ .wave = wave1, .start_point = 0 });
    try composer.append(.{ .wave = wave2, .start_point = 2205 });

    const composition = try composer.finalize(.{});
    defer composition.deinit();

    try std.testing.expectEqual(composition.samples.len, 6615);
    try std.testing.expectEqual(composition.sample_rate, 44100);
    try std.testing.expectEqual(composition.channels, 1);

    // Export to temporary WAV file
    var tmpDir = std.testing.tmpDir(.{});
    defer tmpDir.cleanup();

    {
        var file = try tmpDir.dir.createFile(io, "composition.wav", .{});
        defer file.close(io);
        const buf = try allocator.alloc(u8, 64 * 1024);
        defer allocator.free(buf);
        var writer = file.writer(io, buf);

        try composition.write(.wav, &writer.interface, .{
            .format_code = .pcm,
            .bits = 16,
        });
        try writer.interface.flush();
    }

    // Read back exported WAV file
    const file_bytes = try tmpDir.dir.readFileAlloc(io, "composition.wav", allocator, .limited(64 * 1024));
    defer allocator.free(file_bytes);
    var reader = std.Io.Reader.fixed(file_bytes);

    const read_wave = try Wave(f64).read(.wav, allocator, &reader);
    defer read_wave.deinit();

    try std.testing.expectEqual(read_wave.sample_rate, 44100);
    try std.testing.expectEqual(read_wave.channels, 1);
    try std.testing.expectEqual(read_wave.samples.len, 6615);
}

fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) ![]const f64 {
    var list: std.array_list.Aligned(f64, null) = .empty;

    // Append empty wave
    for (0..length) |_|
        try list.append(allocator, 0.0);

    const result: []const f64 = try list.toOwnedSlice(allocator);

    return result;
}
