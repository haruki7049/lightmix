const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;
const WaveInfo = Composer.WaveInfo;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const composer: Composer = Composer.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();

    const data: []const f32 = generate_soundless_data(44100, allocator);
    defer allocator.free(data);

    const wave = Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer wave.deinit();

    var append_list = std.ArrayList(WaveInfo).init(allocator);
    defer append_list.deinit();
    try append_list.append(.{ .wave = wave, .start_point = 0 });
    try append_list.append(.{ .wave = wave, .start_point = 0 });

    const appended_composer = try composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = try appended_composer.finalize();
    defer result.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try result.write(file);
}

fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) []const f32 {
    var list = std.ArrayList(f32).init(allocator);
    defer list.deinit();

    // Append empty wave
    for (0..length) |_|
        list.append(0.0) catch @panic("Out of memory");

    const result: []const f32 = list.toOwnedSlice() catch @panic("Out of memory");

    return result;
}
