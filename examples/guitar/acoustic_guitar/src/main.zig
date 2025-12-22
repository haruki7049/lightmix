const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const data: [44100]f32 = generate_guitar_note();
    const guitar: Wave = Wave.init(data[0..], allocator, 44100, 1);
    defer guitar.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try guitar.write(file, .f32);
}

// By ChatGPT...
// This function will create Guitar data
fn generate_guitar_note() [44100]f32 {
    const freq: f32 = 440.0;
    const sample_rate: f32 = 44100.0;
    const decay: f32 = 0.996;

    var result: [44100]f32 = undefined;

    const period = @as(usize, @intFromFloat(sample_rate / freq));
    var buffer: [2000]f32 = undefined;
    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();

    for (buffer[0..period]) |*val| {
        val.* = rand.float(f32) * 2.0 - 1.0;
    }

    // Karplus–Strong loop
    var idx: usize = 0;
    var i: usize = 0;
    while (i < result.len) : (i += 1) {
        const next_idx = (idx + 1) % period;
        const avg = (buffer[idx] + buffer[next_idx]) * 0.5 * decay;
        buffer[idx] = avg;
        result[i] = avg;
        idx = next_idx;
    }

    return result;
}
