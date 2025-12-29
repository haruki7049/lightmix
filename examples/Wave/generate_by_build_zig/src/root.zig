const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn generate(options: Options) !Wave {
    std.debug.print("example_option: {d}\n", .{options.example_option});

    const data: [44100]f32 = generate_sinewave_data();
    const result: Wave = Wave.init(data[0..], allocator, .{
        .sample_rate = 44100,
        .channels = 1,
    });

    return result;
}

pub const Options = struct { example_option: u8 };

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
