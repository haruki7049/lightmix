const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_sinewave_data();
    const sinewave: Wave = Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    const half_freq_wave: Wave = sinewave.filter(to_half_freq);
    defer half_freq_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try half_freq_wave.write(file, .i16);
}

fn to_half_freq(original_wave: Wave) !Wave {
    var result: std.array_list.Aligned(f32, null) = .empty;

    for (original_wave.data) |data| {
        try result.append(original_wave.allocator, data);
        try result.append(original_wave.allocator, data);
    }

    return Wave{
        .data = try result.toOwnedSlice(original_wave.allocator),
        .allocator = original_wave.allocator,

        .sample_rate = original_wave.sample_rate,
        .channels = original_wave.channels,
    };
}

fn generate_sinewave_data() [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const radins_per_sec: f32 = 440.0 * 4.0 * std.math.pi;

    var result: [44100]f32 = undefined;
    var i: usize = 0;

    while (i < result.len) : (i += 1) {
        result[i] = 0.5 * std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate);
    }

    return result;
}
