const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const data: []const f32 = generate_soundless_data(44100, allocator);
    defer allocator.free(data);

    const soundless_wave: Wave = Wave.init(data, allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer soundless_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try soundless_wave.write(file, .i16);
}

fn generate_soundless_data(length: usize, allocator: std.mem.Allocator) []const f32 {
    var result: []f32 = allocator.alloc(f32, length) catch @panic("Out of memory");

    for (0..result.len) |i|
        result[i] = 0.0;

    return result;
}
