const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const snare_wave = generate_snare_wave();
    defer snare_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try snare_wave.write(file, .i16);
}

fn generate_snare_wave() Wave {
    const pinknoise_data: [44100]f32 = generate_pink_noise();
    const pinknoise: Wave = Wave.init(pinknoise_data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });

    const sine_data: [44100]f32 = generate_sinewave_data();
    const sinewave: Wave = Wave.init(sine_data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });

    const decayed_pinknoise = pinknoise
        .filter(decay)
        .filter(decay)
        .filter(decay)
        .filter(decay)
        .filter(decay)
        .filter(decay);
    defer decayed_pinknoise.deinit();

    const decayed_sinewave = sinewave
        .filter(decay)
        .filter(decay)
        .filter(half_volume)
        .filter(half_volume);
    defer decayed_sinewave.deinit();

    const result = decayed_pinknoise.mix(decayed_sinewave);
    return result;
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

fn half_volume(original_wave: Wave) !Wave {
    var result: std.array_list.Aligned(f32, null) = .empty;

    for (original_wave.data) |data| {
        try result.append(original_wave.allocator, data / 2.0);
    }

    return Wave{
        .data = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
        .bits = original_wave.bits,
    };
}
