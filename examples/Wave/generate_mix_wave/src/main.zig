const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const sine_data: [44100]f32 = generate_sinewave_data();
    const sinewave: Wave = Wave.init(sine_data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer sinewave.deinit();

    const sawtooth_data: [44100]f32 = generate_sawtooth_wave_data();
    const sawtooth_wave: Wave = Wave.init(sawtooth_data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer sawtooth_wave.deinit();

    const decayed_sawtooth_wave: Wave = sawtooth_wave
        .filter(decay)
        .filter(decay)
        .filter(decay)
        .filter(decay)
        .filter(decay);

    const mixed_wave: Wave = sinewave.mix(decayed_sawtooth_wave);
    defer mixed_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try mixed_wave.write(file);
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

fn generate_sinewave_data() [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const radins_per_sec: f32 = 440.0 * 2.0 * std.math.pi;

    var result: [44100]f32 = undefined;
    var i: usize = 0;

    while (i < result.len) : (i += 1) {
        result[i] = 0.5 * std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate);
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
