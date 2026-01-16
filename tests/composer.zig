const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;
const WaveInfo = lightmix.Composer.WaveInfo;

test "Compose multiple soundless Wave" {
    const allocator = std.testing.allocator;
    const composer: Composer = Composer.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer composer.deinit();

    const data: []const f32 = generate_soundless_data(44100, allocator);
    defer allocator.free(data);

    const wave = Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });
    defer wave.deinit();

    var append_list: std.array_list.Aligned(WaveInfo, null) = .empty;
    defer append_list.deinit(allocator);
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });
    try append_list.append(allocator, .{ .wave = wave, .start_point = 0 });

    const appended_composer = composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = appended_composer.finalize(.{});
    defer result.deinit();

    // Create TmpDir
    var tmpDir = std.testing.tmpDir(.{});
    defer tmpDir.cleanup();

    var file = try tmpDir.dir.createFile("result.wave", .{});
    defer file.close();

    // Write Wave into the file
    try result.write(file, .i16);
}

fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) []const f32 {
    var list: std.array_list.Aligned(f32, null) = .empty;

    // Append empty wave
    for (0..length) |_|
        list.append(allocator, 0.0) catch @panic("Out of memory");

    const result: []const f32 = list.toOwnedSlice(allocator) catch @panic("Out of memory");

    return result;
}
