const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_sinewave_data();
    const sinewave: Wave = Wave.init(data[0..], allocator, 44100, 1, .f32);
    defer sinewave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try sinewave.write(file);
}

const c_5: f32 = 523.251;
const volume: f32 = 1.0;

fn generate_sinewave_data() [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const radins_per_sec: f32 = c_5 * 2.0 * std.math.pi;

    var result: [44100]f32 = undefined;
    var i: usize = 0;

    while (i < result.len) : (i += 1) {
        result[i] = std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate) * volume;
    }

    return result;
}
