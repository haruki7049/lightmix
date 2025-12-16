const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const sinewave: Wave = Wave.from_file_content(@embedFile("./assets/sine.wav"), allocator);

    const overtone_wave: Wave = sinewave.filter(generate_function).filter(generate_function).filter(generate_function);
    defer overtone_wave.deinit();

    var file = try std.fs.cwd().createFile("result.wav", .{});
    defer file.close();

    try overtone_wave.write(file);
}

fn generate_function(original_wave: Wave) !Wave {
    var result: std.array_list.Aligned(f32, null) = .empty;

    for (original_wave.data) |data| {
        const new_data = data * 2;
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
