const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_brown_noise();
    const brown_noise: Wave = Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer brown_noise.deinit();

    const decayed_brown_noise: Wave = brown_noise.filter(decay).filter(decay).filter(decay);
    defer decayed_brown_noise.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try decayed_brown_noise.write(file);
}

fn generate_brown_noise() [44100]f32 {
    var result: [44100]f32 = undefined;

    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    var last: f32 = 0.0;
    var i: usize = 0;
    while (i < result.len) : (i += 1) {
        const white: f32 = rand.float(f32) * 2.0 - 1.0;
        last += white;

        if (last > 1.0)
            last = 1.0;

        if (last < -1.0)
            last = -1.0;

        result[i] = last;
    }

    return result;
}

fn decay(original_wave: Wave) !Wave {
    var result = std.ArrayList(f32).init(original_wave.allocator);

    for (original_wave.data, 0..) |data, n| {
        const i = original_wave.data.len - n;
        const volume: f32 = @as(f32, @floatFromInt(i)) * (1.0 / @as(f32, @floatFromInt(original_wave.data.len)));

        const new_data = data * volume;
        try result.append(new_data);
    }

    return Wave{
        .data = try result.toOwnedSlice(),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
        .bits = original_wave.bits,
    };
}
