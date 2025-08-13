const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const composer = try Composer.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();

    const generators = Wave.Generators.init(allocator);
    const data: []const f32 = try generators.soundless(44100);
    defer generators.free(data);

    const wave = try Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer wave.deinit();

    var append_list = std.ArrayList(Wave).init(allocator);
    defer append_list.deinit();
    try append_list.append(wave);
    try append_list.append(wave);

    const appended_composer = try composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = try appended_composer.finalize();
    defer result.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try result.write(file);
}
