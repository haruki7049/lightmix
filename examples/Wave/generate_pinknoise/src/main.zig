const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_pink_noise();
    const pinknoise: Wave = Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });

    const decayed_pinknoise: Wave = pinknoise.filter(decay).filter(decay).filter(decay);
    defer decayed_pinknoise.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try decayed_pinknoise.write(file);
}

fn generate_pink_noise() [44100]f32 {
    var result: [44100]f32 = undefined;

    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    var b0: f32 = 0.0;
    var b1: f32 = 0.0;
    var b2: f32 = 0.0;

    var i: usize = 0;
    while (i < result.len) : (i += 1) {
        const white: f32 = rand.float(f32) * 2.0 - 1.0;

        b0 = 0.99765 * b0 + white * 0.0990460;
        b1 = 0.96300 * b1 + white * 0.2965164;
        b2 = 0.57000 * b2 + white * 1.0526913;

        const pink: f32 = b0 + b1 + b2 + white * 0.1848;

        result[i] = pink;
    }

    return result;
}

fn decay(original_wave: Wave) !Wave {
    var result: std.array_list.Aligned(f32, null) = .empty;

    for (original_wave.data, 0..) |data, n| {
        const i = original_wave.data.len - n;
        const volume: f32 = @as(f32, @floatFromInt(i)) * (1.0 / @as(f32, @floatFromInt(original_wave.data.len)));

        const new_data = data * volume;
        try result.append(original_wave.allocator, new_data);
    }

    return Wave{
        .data = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
        .bits = original_wave.bits,
    };
}
