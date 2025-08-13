const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const generators = Wave.Generators.init(allocator);
    const data: []const f32 = try generators.soundless(44100);
    defer generators.free(data);

    const soundless_wave: Wave = try Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer soundless_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try soundless_wave.write(file);
}
