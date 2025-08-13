const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const Composer = lightmix.Composer;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const composer = try Composer.init(allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer composer.deinit();

    const data: [44100]f32 = generate_sinewave_data();
    const wave = try Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
        .bits = 16,
    });
    defer wave.deinit();

    const decayed_wave: Wave = wave.filter(decay);
    defer decayed_wave.deinit();

    var append_list = std.ArrayList(Wave).init(allocator);
    defer append_list.deinit();
    try append_list.append(decayed_wave);
    try append_list.append(decayed_wave);

    const appended_composer = try composer.appendSlice(append_list.items);
    defer appended_composer.deinit();

    const result: Wave = try appended_composer.finalize();
    defer result.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try result.write(file);
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

