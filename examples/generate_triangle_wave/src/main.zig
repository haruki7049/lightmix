const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_square_wave_data();
    const square_wave: Wave = try Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer square_wave.deinit();

    const decayed_wave: Wave = square_wave.filter(decay);
    defer decayed_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try decayed_wave.write(file);
}

fn generate_square_wave_data() [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const freq: f32 = 440.0;
    const period: f32 = sample_rate / freq;

    var result: [44100]f32 = undefined;
    var i: usize = 0;

    while (i < result.len) : (i += 1) {
        const phase = @as(f32, @floatFromInt(i % @as(usize, @intFromFloat(period)))) / period;
        const triangle_value = if (phase < 0.5)
            (phase * 4.0) - 1.0       // 前半
        else
            3.0 - (phase * 4.0);      // 後半

        result[i] = triangle_value;
    }

    return result;
}

fn decay(original_wave: Wave) !Wave {
    var result = std.ArrayList(f32).init(original_wave.allocator);

    for (original_wave.data, 1..) |data, n| {
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
