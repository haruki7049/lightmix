const std = @import("std");
const lightmix = @import("lightmix");
const Wave = lightmix.Wave;

test "read sine.wav" {
    const allocator = std.testing.allocator;

    const sine: Wave = Wave.from_file_content(
        .i16,
        @embedFile("./assets/sine.wav"),
        allocator,
    );
    defer sine.deinit();

    const expected_samples: []const f32 = &[_]f32{
        0,
        0.050109863,
        0.10003662,
        0.14959717,
        0.19848633,
        0.24664307,
        0.2939453,
        0.3397827,
        0.3847351,
        0.42770386,
        0.46932983,
        0.5090027,
        0.5465698,
        0.5822449,
        0.6153259,
        0.64624023,
    };
    try std.testing.expectEqualSlices(f32, expected_samples, sine.samples[0..16]);
}
