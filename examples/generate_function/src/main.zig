const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const sinewave: Wave = try Wave.init(@embedFile("./assets/sine.wav"), allocator);
    defer sinewave.deinit();

    const overtone_wave: Wave = sinewave.filter(generate_function).filter(generate_function).filter(generate_function);
    defer overtone_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try overtone_wave.write(file);
}

fn generate_function(original_wave: Wave) !Wave {
    var result = std.ArrayList(f32).init(original_wave.allocator);

    for (original_wave.data) |data| {
        const new_data = data * 2;
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
