const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Synth = lightmix.Synth;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const release_data: [44100]f32 = generate_sinewave_data();
    const synth: Synth = Synth.init(allocator, .{
        .attack = &[_]f32{},
        .decay = &[_]f32{},
        .sustain = &release_data,
        .release = &release_data,

        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer synth.deinit();

    const wave: Wave = synth.finalize();
    defer wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try wave.write(file);
}

fn generate_sinewave_data() [44100]f32 {
    const sample_rate: f32 = 44100.0;
    const radins_per_sec: f32 = 440.0 * 2.0 * std.math.pi;

    var result: [44100]f32 = undefined;
    for (0..result.len) |i| {
        const volume: f32 = 0.5 + @as(f32, @floatFromInt(i)) * (0.5 / @as(f32, @floatFromInt(result.len)));

        result[i] = volume * std.math.sin(@as(f32, @floatFromInt(i)) * radins_per_sec / sample_rate);
    }

    return result;
}
