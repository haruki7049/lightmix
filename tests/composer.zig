const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;

test "Compose multiple soundless Wave" {
    const allocator = std.testing.allocator;
    const composer = Composer(f64).init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    const data: []const f64 = generate_soundless_data(44100, allocator);
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

    const appended_composer = composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result = try appended_composer.finalize(.{});
    defer result.deinit();

    // Create TmpDir
    var tmpDir = std.testing.tmpDir(.{});
    defer tmpDir.cleanup();

    var file = try tmpDir.dir.createFile("result.wav", .{});
    defer file.close();
    const buf = try allocator.alloc(u8, 10 * 1024 * 1024);
    defer allocator.free(buf);
    var writer = file.writer(buf);

    // Write Wave into the file
    try result.write(&writer.interface, .{
        .allocator = allocator,
        .format_code = .pcm,
        .bits = 16,
    });

    try writer.interface.flush();

    // Read the written wave file
    const result_bytes = try tmpDir.dir.readFileAlloc(allocator, "result.wav", 10 * 1024 * 1024);
    defer allocator.free(result_bytes);

    // Read the actual file
    const expected_bytes = try std.fs.cwd().readFileAlloc(allocator, "tests/assets/soundless.wav", 100 * 1024 * 1024);
    defer allocator.free(expected_bytes);

    try std.testing.expectEqualSlices(u8, expected_bytes, result_bytes);
}

fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) []const f64 {
    var list: std.array_list.Aligned(f64, null) = .empty;

    // Append empty wave
    for (0..length) |_|
        list.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f64 = list.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}
