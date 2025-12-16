const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_sawtooth_wave_data();
    const sawtooth_wave: Wave = Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });

    const decayed_wave: Wave = sawtooth_wave.filter(decay);
    defer decayed_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try decayed_wave.write(file);
}

fn generate_sawtooth_wave_data() [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const freq: f32 = 440.0;
    const period: f32 = sample_rate / freq;

    var result: [44100]f32 = undefined;
    var i: usize = 0;

    while (i < result.len) : (i += 1) {
        const phase = @as(f32, @floatFromInt(i % @as(usize, @intFromFloat(period)))) / period;
        result[i] = (phase * 2.0) - 1.0;
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
